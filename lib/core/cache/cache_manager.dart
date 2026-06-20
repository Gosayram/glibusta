import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CacheType { cover, searchResult, metadata, parsedBook, tempFile, thumbnail }

class CachePolicy {
  const CachePolicy({
    required this.type,
    required this.ttl,
    required this.maxSizeBytes,
    this.autoCleanup = false,
  });

  final CacheType type;
  final Duration ttl;
  final int maxSizeBytes;
  final bool autoCleanup;

  static const policies = {
    CacheType.cover: CachePolicy(
      type: CacheType.cover,
      ttl: Duration(days: 30),
      maxSizeBytes: 100 * 1024 * 1024,
      autoCleanup: true,
    ),
    CacheType.searchResult: CachePolicy(
      type: CacheType.searchResult,
      ttl: Duration(minutes: 5),
      maxSizeBytes: 5 * 1024 * 1024,
    ),
    CacheType.metadata: CachePolicy(
      type: CacheType.metadata,
      ttl: Duration(hours: 6),
      maxSizeBytes: 20 * 1024 * 1024,
    ),
    CacheType.parsedBook: CachePolicy(
      type: CacheType.parsedBook,
      ttl: Duration(days: 7),
      maxSizeBytes: 50 * 1024 * 1024,
      autoCleanup: true,
    ),
    CacheType.tempFile: CachePolicy(
      type: CacheType.tempFile,
      ttl: Duration(hours: 1),
      maxSizeBytes: 50 * 1024 * 1024,
      autoCleanup: true,
    ),
    CacheType.thumbnail: CachePolicy(
      type: CacheType.thumbnail,
      ttl: Duration(days: 14),
      maxSizeBytes: 30 * 1024 * 1024,
      autoCleanup: true,
    ),
  };
}

class CachedEntry {
  CachedEntry({
    required this.key,
    required this.type,
    required this.filePath,
    required this.sizeBytes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String key;
  final CacheType type;
  final String filePath;
  final int sizeBytes;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;

  Map<String, dynamic> toJson() => {
    'key': key,
    'type': type.name,
    'filePath': filePath,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
  };
}

class CacheManager {
  CacheManager(this._cacheDir);
  final Directory _cacheDir;

  static const _maxIndexEntriesBeforeCleanup = 200;
  final Map<String, CachedEntry> _index = {};
  Timer? _cleanupTimer;

  Future<void> init() async {
    await _cacheDir.create(recursive: true);
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _cleanupExpired(),
    );
  }

  Future<String> getCachePath(CacheType type) async {
    final dir = Directory('${_cacheDir.path}/${type.name}');
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> put({
    required String key,
    required CacheType type,
    required String filePath,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) return;

    final typeDir = Directory('${_cacheDir.path}/${type.name}');
    await typeDir.create(recursive: true);
    final cachedPath = '${typeDir.path}/$key';
    final cachedFile = File(cachedPath);
    await sourceFile.copy(cachedPath);

    final stat = await cachedFile.stat();
    final policy = CachePolicy.policies[type]!;

    if (_index.length > _maxIndexEntriesBeforeCleanup) {
      unawaited(_cleanupExpired());
    }

    _index[key] = CachedEntry(
      key: key,
      type: type,
      filePath: cachedPath,
      sizeBytes: stat.size,
    );

    if (_shouldEnforceLimit(type)) {
      await _enforceLimit(type, policy.maxSizeBytes);
    }
  }

  Future<String?> get(String key) async {
    final entry = _index[key];
    if (entry == null) return null;

    final policy = CachePolicy.policies[entry.type]!;
    if (entry.isExpired(policy.ttl)) {
      await _removeEntry(entry);
      return null;
    }

    final file = File(entry.filePath);
    if (!await file.exists()) {
      _index.remove(key);
      return null;
    }

    return entry.filePath;
  }

  Future<void> remove(String key) async {
    final entry = _index.remove(key);
    if (entry != null) {
      await _removeEntry(entry);
    }
  }

  Future<void> clearType(CacheType type) async {
    final keys = _index.keys.where((k) => _index[k]?.type == type).toList();
    for (final key in keys) {
      await remove(key);
    }
  }

  Future<void> clearAll() async {
    for (final key in _index.keys.toList()) {
      await remove(key);
    }
  }

  int sizeBytes() => _index.values.fold(0, (sum, e) => sum + e.sizeBytes);

  Map<CacheType, int> sizeByType() {
    final result = <CacheType, int>{};
    for (final entry in _index.values) {
      result[entry.type] = (result[entry.type] ?? 0) + entry.sizeBytes;
    }
    return result;
  }

  Future<void> _cleanupExpired() async {
    final expired = _index.values.where((entry) {
      final policy = CachePolicy.policies[entry.type]!;
      return entry.isExpired(policy.ttl);
    }).toList();

    for (final entry in expired) {
      await _removeEntry(entry);
    }
  }

  Future<void> _removeEntry(CachedEntry entry) async {
    _index.remove(entry.key);
    final file = File(entry.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  bool _shouldEnforceLimit(CacheType type) {
    return type == CacheType.tempFile || type == CacheType.cover;
  }

  Future<void> _enforceLimit(CacheType type, int maxBytes) async {
    final entries = _index.values.where((e) => e.type == type).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    var totalSize = entries.fold(0, (int sum, e) => sum + e.sizeBytes);
    for (final entry in entries) {
      if (totalSize <= maxBytes) break;
      totalSize -= entry.sizeBytes;
      await _removeEntry(entry);
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }
}

// --- Riverpod providers ---

final cacheManagerProvider = Provider<CacheManager>((ref) {
  throw StateError(
    'cacheManagerProvider must be overridden at startup with a configured CacheManager instance.',
  );
});

final cacheSizeProvider = Provider<int>((ref) {
  final manager = ref.watch(cacheManagerProvider);
  return manager.sizeBytes();
});

final cacheSizeByTypeProvider = Provider<Map<CacheType, int>>((ref) {
  final manager = ref.watch(cacheManagerProvider);
  return manager.sizeByType();
});

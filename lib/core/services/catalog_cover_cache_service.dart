import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../platform/app_file_storage.dart';

final catalogCoverCacheServiceProvider = Provider<CatalogCoverCacheService>((
  ref,
) {
  final storage = ref.watch(appFileStorageProvider);
  return CatalogCoverCacheService(storage);
});

class CatalogCoverCacheService {
  CatalogCoverCacheService(this._storage);

  final AppFileStorage _storage;

  Future<File?> getCover(String url) async {
    final file = await _fileForUrl(url);
    if (await file.exists()) return file;
    return null;
  }

  Future<void> putCover(String url, Uint8List bytes) async {
    final file = await _fileForUrl(url);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<bool> hasCover(String url) async {
    final file = await _fileForUrl(url);
    return file.exists();
  }

  Future<void> removeCover(String url) async {
    final file = await _fileForUrl(url);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<int> getCacheSize() async {
    final dir = await _storage.catalogCoversDir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearExpired({Duration maxAge = const Duration(days: 30)}) async {
    final dir = await _storage.catalogCoversDir();
    if (!await dir.exists()) return;
    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in dir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
  }

  Future<void> clearAll() async {
    final dir = await _storage.catalogCoversDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }

  Future<File> _fileForUrl(String url) async {
    final dir = await _storage.catalogCoversDir();
    final sanitized = url
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'\?.*'), '');
    final name = sanitized.length > 200 ? sanitized.substring(0, 200) : sanitized;
    return File(p.join(dir.path, '$name.jpg'));
  }
}

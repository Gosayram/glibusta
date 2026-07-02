import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../utils/format_utils.dart';

class CleanupResult {
  const CleanupResult({
    required this.tempFilesRemoved,
    required this.cacheFilesRemoved,
    required this.orphanFilesFound,
    required this.heavyBooks,
    required this.bytesFreed,
  });

  final int tempFilesRemoved;
  final int cacheFilesRemoved;
  final int orphanFilesFound;
  final List<HeavyBook> heavyBooks;
  final int bytesFreed;
}

class HeavyBook {
  const HeavyBook({
    required this.id,
    required this.title,
    required this.filePath,
    required this.sizeBytes,
  });

  final String id;
  final String title;
  final String filePath;
  final int sizeBytes;

  String get sizeHuman => formatBytes(sizeBytes);
}

class SmartCleanupService {
  SmartCleanupService(this._db, this._logger);
  final AppDatabase _db;
  final AppLogger _logger;

  Future<(int count, int bytes)> cleanupTempFiles(String tempDir) async {
    int count = 0;
    int bytes = 0;
    try {
      final dir = Directory(tempDir);
      if (!await dir.exists()) return (0, 0);

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified) > const Duration(hours: 1)) {
            bytes += stat.size;
            await entity.delete();
            count++;
          }
        }
      }
    } on Object catch (e) {
      _logger.warning('Temp cleanup failed: $e', name: 'Cleanup');
    }
    _logger.info('Cleaned $count temp files ($bytes bytes)', name: 'Cleanup');
    return (count, bytes);
  }

  Future<int> cleanupCacheFiles(String cacheDir) async {
    int count = 0;
    try {
      final dir = Directory(cacheDir);
      if (!await dir.exists()) return 0;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.json' || ext == '.tmp' || ext == '.cache') {
            final stat = await entity.stat();
            if (DateTime.now().difference(stat.modified) > const Duration(days: 7)) {
              await entity.delete();
              count++;
            }
          }
        }
      }
    } on Object catch (e) {
      _logger.warning('Cache cleanup failed: $e', name: 'Cleanup');
    }
    return count;
  }

  Future<List<String>> findOrphanFiles(String booksDir) async {
    final orphans = <String>[];
    try {
      final books = await _db.select(_db.savedBooks).get();
      final dbPaths = books.map((b) => b.filePath).toSet();

      final dir = Directory(booksDir);
      if (!await dir.exists()) return [];

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && !dbPaths.contains(entity.path)) {
          orphans.add(entity.path);
        }
      }
    } on Object catch (e) {
      _logger.warning('Orphan detection failed: $e', name: 'Cleanup');
    }
    return orphans;
  }

  Future<List<HeavyBook>> findHeavyBooks({
    int topN = 10,
    int minSizeBytes = 5 * 1024 * 1024,
  }) async {
    final heavy = <HeavyBook>[];
    try {
      final books = await (_db.select(
        _db.savedBooks,
      )..where((b) => b.fileSize.isBiggerOrEqualValue(minSizeBytes))).get();

      for (final book in books) {
        final file = File(book.filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          heavy.add(
            HeavyBook(
              id: book.id,
              title: book.title,
              filePath: book.filePath,
              sizeBytes: stat.size,
            ),
          );
        }
      }

      heavy.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    } on Object catch (e) {
      _logger.warning('Heavy book detection failed: $e', name: 'Cleanup');
    }
    return heavy.take(topN).toList();
  }

  Future<CleanupResult> runFullCleanup({
    required String tempDir,
    required String cacheDir,
    required String booksDir,
  }) async {
    _logger.info('Starting full cleanup...', name: 'Cleanup');

    final (tempCount, tempBytes) = await cleanupTempFiles(tempDir);
    final cacheCount = await cleanupCacheFiles(cacheDir);
    final orphans = await findOrphanFiles(booksDir);
    final heavy = await findHeavyBooks();

    _logger.info(
      'Cleanup complete: $tempCount temp, $cacheCount cache, ${orphans.length} orphans',
      name: 'Cleanup',
    );

    return CleanupResult(
      tempFilesRemoved: tempCount,
      cacheFilesRemoved: cacheCount,
      orphanFilesFound: orphans.length,
      heavyBooks: heavy,
      bytesFreed: tempBytes,
    );
  }
}

// --- Riverpod providers ---

final smartCleanupServiceProvider = Provider<SmartCleanupService>((ref) {
  throw StateError(
    'smartCleanupServiceProvider must be overridden at startup with a configured SmartCleanupService instance.',
  );
});

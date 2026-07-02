import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/services/smart_cleanup_service.dart';
import 'package:glibusta/core/storage/storage_info_model.dart';

void main() {
  group('StorageInfoModel', () {
    test('totalBytes sums all categories', () {
      const model = StorageInfoModel(
        categories: [
          StorageCategory(name: 'DB', icon: 'database', sizeBytes: 100),
          StorageCategory(name: 'Books', icon: 'book', sizeBytes: 200),
          StorageCategory(name: 'Cache', icon: 'cache', sizeBytes: 50),
        ],
      );
      expect(model.totalBytes, 350);
    });

    test('totalHuman formats correctly', () {
      const model = StorageInfoModel(
        categories: [
          StorageCategory(name: 'DB', icon: 'database', sizeBytes: 1024),
        ],
      );
      expect(model.totalHuman, contains('KB'));
    });

    test('empty categories totals to 0', () {
      const model = StorageInfoModel(categories: []);
      expect(model.totalBytes, 0);
      expect(model.totalHuman, '0 B');
    });

    test('sizeHuman on category works', () {
      const cat = StorageCategory(name: 'Test', icon: 'test', sizeBytes: 2048);
      expect(cat.sizeHuman, contains('KB'));
    });
  });

  group('SmartCleanupService - filesystem methods', () {
    late SmartCleanupService service;
    late Directory tempDir;
    late Directory cacheDir;

    setUp(() {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      service = SmartCleanupService(db, AppLogger());
      tempDir = Directory.systemTemp.createTempSync('cleanup_test_temp_');
      cacheDir = Directory.systemTemp.createTempSync('cleanup_test_cache_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      cacheDir.deleteSync(recursive: true);
    });

    group('cleanupTempFiles', () {
      test('returns (0, 0) for non-existent directory', () async {
        final (count, bytes) = await service.cleanupTempFiles('/nonexistent/path');
        expect(count, 0);
        expect(bytes, 0);
      });

      test('deletes files older than 1 hour', () async {
        final oldFile = File('${tempDir.path}/old_file.txt');
        oldFile.writeAsStringSync('old data');
        oldFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

        final (count, bytes) = await service.cleanupTempFiles(tempDir.path);
        expect(count, 1);
        expect(bytes, greaterThan(0));
        expect(oldFile.existsSync(), isFalse);
      });

      test('preserves files less than 1 hour old', () async {
        final newFile = File('${tempDir.path}/new_file.txt');
        newFile.writeAsStringSync('new data');

        final (count, _) = await service.cleanupTempFiles(tempDir.path);
        expect(count, 0);
        expect(newFile.existsSync(), isTrue);
      });

      test('handles empty directory', () async {
        final (count, bytes) = await service.cleanupTempFiles(tempDir.path);
        expect(count, 0);
        expect(bytes, 0);
      });

      test('deletes files in subdirectories', () async {
        final subDir = Directory('${tempDir.path}/sub');
        subDir.createSync();
        final oldFile = File('${subDir.path}/nested.txt');
        oldFile.writeAsStringSync('nested');
        oldFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 3)));

        final (count, _) = await service.cleanupTempFiles(tempDir.path);
        expect(count, 1);
        expect(oldFile.existsSync(), isFalse);
      });

      test('reports correct bytes freed', () async {
        final oldFile = File('${tempDir.path}/data.bin');
        final data = List<int>.filled(1024, 42);
        oldFile.writeAsBytesSync(data);
        oldFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

        final (_, bytes) = await service.cleanupTempFiles(tempDir.path);
        expect(bytes, 1024);
      });
    });

    group('cleanupCacheFiles', () {
      test('returns 0 for non-existent directory', () async {
        final count = await service.cleanupCacheFiles('/nonexistent/path');
        expect(count, 0);
      });

      test('deletes .json files older than 7 days', () async {
        final oldJson = File('${cacheDir.path}/old.json');
        oldJson.writeAsStringSync('{}');
        oldJson.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 8)));

        final count = await service.cleanupCacheFiles(cacheDir.path);
        expect(count, 1);
        expect(oldJson.existsSync(), isFalse);
      });

      test('preserves recent .json files', () async {
        final recentJson = File('${cacheDir.path}/recent.json');
        recentJson.writeAsStringSync('{}');

        final count = await service.cleanupCacheFiles(cacheDir.path);
        expect(count, 0);
        expect(recentJson.existsSync(), isTrue);
      });

      test('deletes .tmp files older than 7 days', () async {
        final oldTmp = File('${cacheDir.path}/old.tmp');
        oldTmp.writeAsStringSync('');
        oldTmp.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));

        final count = await service.cleanupCacheFiles(cacheDir.path);
        expect(count, 1);
      });

      test('deletes .cache files older than 7 days', () async {
        final oldCache = File('${cacheDir.path}/old.cache');
        oldCache.writeAsStringSync('');
        oldCache.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));

        final count = await service.cleanupCacheFiles(cacheDir.path);
        expect(count, 1);
      });

      test('preserves non-cache file types even when old', () async {
        final log = File('${cacheDir.path}/log.txt');
        log.writeAsStringSync('');
        log.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 30)));

        final count = await service.cleanupCacheFiles(cacheDir.path);
        expect(count, 0);
        expect(log.existsSync(), isTrue);
      });

      test('handles mixed old and new cache files', () async {
        final old1 = File('${cacheDir.path}/a.json');
        old1.writeAsStringSync('');
        old1.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));

        final old2 = File('${cacheDir.path}/b.tmp');
        old2.writeAsStringSync('');
        old2.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));

        final fresh = File('${cacheDir.path}/c.json');
        fresh.writeAsStringSync('');

        final count = await service.cleanupCacheFiles(cacheDir.path);
        expect(count, 2);
        expect(fresh.existsSync(), isTrue);
      });
    });

    group('findOrphanFiles', () {
      test('returns empty for non-existent directory', () async {
        final orphans = await service.findOrphanFiles('/nonexistent/path');
        expect(orphans, isEmpty);
      });

      test('finds files not in DB', () async {
        final orphanFile = File('${tempDir.path}/orphan.epub');
        orphanFile.writeAsStringSync('book data');

        final orphans = await service.findOrphanFiles(tempDir.path);
        expect(orphans, contains(orphanFile.path));
      });

      test('returns empty for empty directory', () async {
        final orphans = await service.findOrphanFiles(tempDir.path);
        expect(orphans, isEmpty);
      });
    });

    group('findHeavyBooks', () {
      test('returns empty list with empty DB', () async {
        final heavy = await service.findHeavyBooks();
        expect(heavy, isEmpty);
      });
    });

    group('HeavyBook', () {
      test('sizeHuman formats correctly', () {
        const book = HeavyBook(
          id: '1',
          title: 'Test',
          filePath: '/path',
          sizeBytes: 1024 * 1024,
        );
        expect(book.sizeHuman, contains('MB'));
      });
    });
  });
}

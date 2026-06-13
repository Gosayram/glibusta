import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('DownloadDao', () {
    test('insertDownload and getAllDownloads', () async {
      await db.downloadDao.insertDownload(
        const DownloadsCompanion(
          id: Value('d1'),
          bookId: Value('b1'),
          bookTitle: Value('Book 1'),
          format: Value('epub'),
          sourceUrl: Value('https://example.com/1.epub'),
          status: Value(DownloadStatusDb.queued),
        ),
      );
      final all = await db.downloadDao.getAllDownloads();
      expect(all.length, 1);
      expect(all.first.bookTitle, 'Book 1');
    });

    test('getDownloadById returns correct download', () async {
      await db.downloadDao.insertDownload(
        const DownloadsCompanion(
          id: Value('d1'),
          bookId: Value('b1'),
          bookTitle: Value('Book 1'),
          format: Value('epub'),
          sourceUrl: Value('https://example.com/1.epub'),
          status: Value(DownloadStatusDb.queued),
        ),
      );
      final dl = await db.downloadDao.getDownloadById('d1');
      expect(dl, isNotNull);
      expect(dl!.id, 'd1');
    });

    test('getDownloadById returns null for missing', () async {
      final dl = await db.downloadDao.getDownloadById('missing');
      expect(dl, isNull);
    });

    test('updateDownloadStatus changes status', () async {
      await db.downloadDao.insertDownload(
        const DownloadsCompanion(
          id: Value('d1'),
          bookId: Value('b1'),
          bookTitle: Value('Book 1'),
          format: Value('epub'),
          sourceUrl: Value('https://example.com/1.epub'),
          status: Value(DownloadStatusDb.queued),
        ),
      );
      await db.downloadDao.updateDownloadStatus('d1', DownloadStatusDb.running);
      final dl = await db.downloadDao.getDownloadById('d1');
      expect(dl!.status, DownloadStatusDb.running);
    });

    test('updateDownloadProgress updates bytes', () async {
      await db.downloadDao.insertDownload(
        const DownloadsCompanion(
          id: Value('d1'),
          bookId: Value('b1'),
          bookTitle: Value('Book 1'),
          format: Value('epub'),
          sourceUrl: Value('https://example.com/1.epub'),
          status: Value(DownloadStatusDb.queued),
        ),
      );
      await db.downloadDao.updateDownloadProgress('d1', 500, 1000);
      final dl = await db.downloadDao.getDownloadById('d1');
      expect(dl!.downloadedBytes, 500);
      expect(dl.totalBytes, 1000);
    });

    test('deleteDownload removes entry', () async {
      await db.downloadDao.insertDownload(
        const DownloadsCompanion(
          id: Value('d1'),
          bookId: Value('b1'),
          bookTitle: Value('Book 1'),
          format: Value('epub'),
          sourceUrl: Value('https://example.com/1.epub'),
          status: Value(DownloadStatusDb.queued),
        ),
      );
      await db.downloadDao.deleteDownload('d1');
      final dl = await db.downloadDao.getDownloadById('d1');
      expect(dl, isNull);
    });

    test('watchAllDownloads emits initial empty list', () async {
      final completer = Completer<List<Download>>();
      final sub = db.downloadDao.watchAllDownloads().listen((downloads) {
        if (!completer.isCompleted) completer.complete(downloads);
      });
      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(result, isEmpty);
      await sub.cancel();
    });
  });
}

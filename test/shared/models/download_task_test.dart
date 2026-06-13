import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/download_task.dart';

void main() {
  group('DownloadTask', () {
    test('stores all fields', () {
      const task = DownloadTask(
        id: 'dl-1',
        bookId: 'book-1',
        bookTitle: 'Test Book',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/book.epub',
        targetPath: '/tmp/book.epub',
        status: DownloadStatus.queued,
        downloadedBytes: 0,
        totalBytes: 1024,
      );
      expect(task.id, 'dl-1');
      expect(task.bookId, 'book-1');
      expect(task.bookTitle, 'Test Book');
      expect(task.format, BookFormat.epub);
      expect(task.sourceUrl, contains('epub'));
      expect(task.targetPath, '/tmp/book.epub');
      expect(task.status, DownloadStatus.queued);
      expect(task.downloadedBytes, 0);
      expect(task.totalBytes, 1024);
    });

    test('nullable fields', () {
      const task = DownloadTask(
        id: 'dl-2',
        bookId: 'b',
        format: BookFormat.fb2,
        sourceUrl: 'url',
        targetPath: null,
        status: DownloadStatus.running,
        downloadedBytes: null,
        totalBytes: null,
      );
      expect(task.bookTitle, isNull);
      expect(task.targetPath, isNull);
      expect(task.downloadedBytes, isNull);
      expect(task.totalBytes, isNull);
    });
  });

  group('DownloadStatus', () {
    test('has all statuses', () {
      expect(DownloadStatus.values.length, 6);
      expect(DownloadStatus.values, contains(DownloadStatus.queued));
      expect(DownloadStatus.values, contains(DownloadStatus.running));
      expect(DownloadStatus.values, contains(DownloadStatus.paused));
      expect(DownloadStatus.values, contains(DownloadStatus.completed));
      expect(DownloadStatus.values, contains(DownloadStatus.failed));
      expect(DownloadStatus.values, contains(DownloadStatus.canceled));
    });
  });

  group('BookDetails', () {
    test('stores all fields', () {
      const details = BookDetails(
        book: Book(
          id: '1',
          title: 'Test',
          authorIds: ['a1'],
          genreIds: ['g1'],
          description: 'desc',
          coverUrl: 'cover.jpg',
          publishDate: null,
          availableFormats: [BookFormat.epub],
          source: BookSourceInfo(sourceId: 's', sourceUrl: 'u'),
        ),
        description: 'Full description',
        availableFormats: [BookFormat.epub, BookFormat.fb2],
        downloadUrls: ['https://example.com/book.epub'],
      );
      expect(details.book.title, 'Test');
      expect(details.description, 'Full description');
      expect(details.availableFormats.length, 2);
      expect(details.downloadUrls.length, 1);
    });

    test('nullable fields', () {
      const details = BookDetails(
        book: Book(
          id: '1',
          title: 'T',
          authorIds: [],
          genreIds: [],
          description: null,
          coverUrl: null,
          publishDate: null,
          availableFormats: [],
          source: BookSourceInfo(sourceId: 's', sourceUrl: 'u'),
        ),
        description: null,
        availableFormats: [],
        downloadUrls: [],
      );
      expect(details.description, isNull);
      expect(details.availableFormats, isEmpty);
      expect(details.downloadUrls, isEmpty);
    });
  });
}

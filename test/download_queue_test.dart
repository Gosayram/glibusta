import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/notifications/download_notification_service.dart';
import 'package:glibusta/features/downloads/data/background_download_service.dart';
import 'package:glibusta/features/downloads/domain/download_repository.dart';
import 'package:glibusta/features/downloads/presentation/download_queue.dart';
import 'package:glibusta/features/library/data/book_import_service.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/download_task.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

class MockBackgroundDownloadService extends Mock implements BackgroundDownloadService {}

class MockDownloadNotificationService extends Mock implements DownloadNotificationService {}

class MockBookImportService extends Mock implements BookImportService {}

void main() {
  late MockDownloadRepository mockRepo;
  late MockBackgroundDownloadService mockBgDownload;
  late MockDownloadNotificationService mockNotificationService;
  late MockBookImportService mockBookImport;

  setUpAll(() {
    registerFallbackValue(DownloadStatus.queued);
    registerFallbackValue(DownloadStatus.running);
    registerFallbackValue(BookFormat.epub);
    registerFallbackValue(
      const DownloadTask(
        id: '',
        bookId: '',
        format: BookFormat.epub,
        sourceUrl: '',
        targetPath: '',
        status: DownloadStatus.queued,
        downloadedBytes: 0,
        totalBytes: 0,
      ),
    );
  });

  setUp(() {
    mockRepo = MockDownloadRepository();
    mockBgDownload = MockBackgroundDownloadService();
    mockNotificationService = MockDownloadNotificationService();
    mockBookImport = MockBookImportService();
    when(() => mockNotificationService.cancel(any())).thenAnswer((_) async {});
    when(() => mockNotificationService.showCompleted(any())).thenAnswer((_) async {});
    when(() => mockNotificationService.showFailed(any(), any())).thenAnswer((_) async {});
    when(
      () => mockNotificationService.showProgress(
        task: any(named: 'task'),
        speedBytesPerSec: any(named: 'speedBytesPerSec'),
      ),
    ).thenAnswer((_) async {});
  });

  group('DownloadQueue.enqueue', () {
    test('calls repo.startDownload with correct params', () async {
      const task = DownloadTask(
        id: 'task-1',
        bookId: 'book-1',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b/book-1/epub',
        targetPath: '/tmp/book-1.epub',
        status: DownloadStatus.queued,
        downloadedBytes: 0,
        totalBytes: 0,
      );

      when(
        () => mockRepo.startDownload(
          bookId: 'book-1',
          bookTitle: 'Test Book',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b/book-1/epub',
        ),
      ).thenAnswer((_) async => task);
      when(() => mockRepo.updateStatus(any(), any())).thenAnswer((_) async {});
      when(
        () => mockBgDownload.enqueue(
          taskId: any(named: 'taskId'),
          bookId: any(named: 'bookId'),
          bookTitle: any(named: 'bookTitle'),
          format: any(named: 'format'),
          sourceUrl: any(named: 'sourceUrl'),
        ),
      ).thenAnswer((_) async => 'task-1');

      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );

      await queue.enqueue(
        bookId: 'book-1',
        bookTitle: 'Test Book',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b/book-1/epub',
      );

      verify(
        () => mockRepo.startDownload(
          bookId: 'book-1',
          bookTitle: 'Test Book',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b/book-1/epub',
        ),
      ).called(1);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      queue.dispose();
    });
  });

  group('DownloadQueue.remove', () {
    test('calls repo.removeDownload', () async {
      when(() => mockRepo.removeDownload(any())).thenAnswer((_) async {});

      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      await queue.remove('task-99');

      verify(() => mockRepo.removeDownload('task-99')).called(1);

      queue.dispose();
    });
  });

  test(
    'emits updated download data when progress changes',
    () async {
      const task = DownloadTask(
        id: 'task-progress',
        bookId: 'book-1',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b/book-1/epub',
        targetPath: '/tmp/book-1.epub',
        status: DownloadStatus.running,
        downloadedBytes: 0,
        totalBytes: 100,
      );
      when(
        () => mockRepo.startDownload(
          bookId: 'book-1',
          bookTitle: 'Test Book',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b/book-1/epub',
        ),
      ).thenAnswer((_) async => task);
      when(
        () => mockBgDownload.enqueue(
          taskId: any(named: 'taskId'),
          bookId: any(named: 'bookId'),
          bookTitle: any(named: 'bookTitle'),
          format: any(named: 'format'),
          sourceUrl: any(named: 'sourceUrl'),
        ),
      ).thenAnswer((_) async => task.id);

      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      final progressUpdate = Completer<List<DownloadTask>>();
      final updates = queue.onDownloadsChanged.listen((tasks) {
        if (tasks.length == 1 &&
            tasks.single.downloadedBytes == 50 &&
            !progressUpdate.isCompleted) {
          progressUpdate.complete(tasks);
        }
      });
      addTearDown(() async {
        await updates.cancel();
        queue.dispose();
      });

      await Future<void>.delayed(Duration.zero);
      await queue.enqueue(
        bookId: 'book-1',
        bookTitle: 'Test Book',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b/book-1/epub',
      );
      queue.onProgressChanged(task.id, 50, 100);

      expect(await progressUpdate.future, hasLength(1));
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );
}

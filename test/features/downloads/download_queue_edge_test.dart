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
    registerFallbackValue(BookFormat.epub);
    registerFallbackValue(
      const DownloadTask(
        id: '',
        bookId: '',
        bookTitle: '',
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
    when(() => mockRepo.removeDownload(any())).thenAnswer((_) async {});
    when(() => mockRepo.cancelDownload(any())).thenAnswer((_) async {});
    when(() => mockRepo.updateStatus(any(), any())).thenAnswer((_) async {});
    when(() => mockRepo.getAllDownloads()).thenAnswer((_) async => const []);
  });

  group('pause', () {
    test('ignores non-running task', () async {
      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      await queue.pause('nonexistent');
      verifyNever(() => mockRepo.updateStatus(any(), any()));
      queue.dispose();
    });
  });

  group('cancel', () {
    test('cancels nonexistent task without error', () async {
      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      await queue.cancel('nonexistent');
      verifyNever(() => mockRepo.cancelDownload(any()));
      queue.dispose();
    });
  });

  group('remove', () {
    test('removes task from queue and calls repo', () async {
      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      await queue.remove('nonexistent');
      verify(() => mockRepo.removeDownload('nonexistent')).called(1);
      queue.dispose();
    });
  });

  group('onDownloadsChanged', () {
    test('emits empty list initially', () async {
      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      final tasks = await queue.onDownloadsChanged.first.timeout(const Duration(seconds: 2));
      expect(tasks, isEmpty);
      queue.dispose();
    });
  });

  group('enqueue', () {
    test('calls repo.startDownload and adds task', () async {
      const task = DownloadTask(
        id: 'task-1',
        bookId: 'b1',
        bookTitle: 'Book 1',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b1.epub',
        targetPath: '/tmp/b1.epub',
        status: DownloadStatus.queued,
        downloadedBytes: 0,
        totalBytes: 0,
      );

      when(
        () => mockRepo.startDownload(
          bookId: 'b1',
          bookTitle: 'Book 1',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b1.epub',
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
      ).thenAnswer((_) async => 'task-1');

      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );
      await queue.enqueue(
        bookId: 'b1',
        bookTitle: 'Book 1',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b1.epub',
      );

      verify(
        () => mockRepo.startDownload(
          bookId: 'b1',
          bookTitle: 'Book 1',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b1.epub',
        ),
      ).called(1);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      queue.dispose();
    });

    test('marks the task failed when the native downloader rejects it', () async {
      const task = DownloadTask(
        id: 'task-1',
        bookId: 'b1',
        bookTitle: 'Book 1',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b1.epub',
        targetPath: '/tmp/b1.epub',
        status: DownloadStatus.queued,
        downloadedBytes: 0,
        totalBytes: 0,
      );
      when(
        () => mockRepo.startDownload(
          bookId: 'b1',
          bookTitle: 'Book 1',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b1.epub',
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
      ).thenThrow(StateError('native scheduler unavailable'));

      final queue = DownloadQueue(
        mockRepo,
        mockBgDownload,
        mockNotificationService,
        mockBookImport,
      );

      await expectLater(
        queue.enqueue(
          bookId: 'b1',
          bookTitle: 'Book 1',
          format: BookFormat.epub,
          sourceUrl: 'https://example.com/b1.epub',
        ),
        throwsA(isA<StateError>()),
      );

      verify(() => mockRepo.updateStatus('task-1', DownloadStatus.failed)).called(1);
      queue.dispose();
    });
  });
}

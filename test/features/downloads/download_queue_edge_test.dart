import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/http/http_client.dart';
import 'package:glibusta/core/notifications/download_notification_service.dart';
import 'package:glibusta/features/downloads/domain/download_repository.dart';
import 'package:glibusta/features/downloads/presentation/download_queue.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/download_task.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

class MockHttpClient extends Mock implements HttpClient {}

class MockDownloadNotificationService extends Mock implements DownloadNotificationService {}

void main() {
  late MockDownloadRepository mockRepo;
  late MockHttpClient mockClient;
  late MockDownloadNotificationService mockNotificationService;

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
    mockClient = MockHttpClient();
    mockNotificationService = MockDownloadNotificationService();
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
  });

  group('setMaxConcurrent', () {
    test('reduces concurrency', () {
      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
      queue.setMaxConcurrent(1);
      queue.dispose();
    });
  });

  group('pause', () {
    test('ignores non-running task', () async {
      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
      await queue.pause('nonexistent');
      verifyNever(() => mockRepo.updateStatus(any(), any()));
      queue.dispose();
    });
  });

  group('cancel', () {
    test('cancels nonexistent task without error', () async {
      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
      await queue.cancel('nonexistent');
      verifyNever(() => mockRepo.cancelDownload(any()));
      queue.dispose();
    });
  });

  group('remove', () {
    test('removes task from queue and calls repo', () async {
      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
      await queue.remove('nonexistent');
      verify(() => mockRepo.removeDownload('nonexistent')).called(1);
      queue.dispose();
    });
  });

  group('onDownloadsChanged', () {
    test('emits empty list initially', () async {
      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
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
        () => mockClient.download(any(), any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});

      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
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
  });

  group('download failure', () {
    test('marks task as failed after retries on error', () async {
      const task = DownloadTask(
        id: 'fail-1',
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
        () => mockClient.download(any(), any(), onProgress: any(named: 'onProgress')),
      ).thenThrow(Exception('network error'));

      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
      await queue.enqueue(
        bookId: 'b1',
        bookTitle: 'Book 1',
        format: BookFormat.epub,
        sourceUrl: 'https://example.com/b1.epub',
      );

      // Retry delays: 1s + 2s + 4s = 7s, plus margin
      await Future<void>.delayed(const Duration(seconds: 8));
      verify(() => mockNotificationService.showFailed(any(), any())).called(1);
      queue.dispose();
    });
  });
}

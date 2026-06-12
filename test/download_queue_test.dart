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
    registerFallbackValue(DownloadStatus.running);
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
        () => mockClient.download(any(), any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});

      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);

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

      final queue = DownloadQueue(mockRepo, mockClient, mockNotificationService);
      await queue.remove('task-99');

      verify(() => mockRepo.removeDownload('task-99')).called(1);

      queue.dispose();
    });
  });
}

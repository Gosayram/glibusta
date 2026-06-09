import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';

abstract class DownloadRepository {
  Stream<List<DownloadTask>> watchAllDownloads();
  Future<List<DownloadTask>> getAllDownloads();
  Future<DownloadTask?> getDownloadById(String id);

  Future<DownloadTask> startDownload({
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  });

  Future<void> updateProgress(String taskId, int downloaded, int total);
  Future<void> updateStatus(String taskId, DownloadStatus status);
  Future<void> cancelDownload(String taskId);
  Future<void> removeDownload(String taskId);
}

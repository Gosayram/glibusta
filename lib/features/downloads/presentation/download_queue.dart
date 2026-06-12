import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/http_client.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../data/download_repository.dart';
import '../domain/download_repository.dart';

final downloadQueueProvider = Provider<DownloadQueue>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  final httpClient = ref.watch(httpClientProvider);
  final queue = DownloadQueue(repository, httpClient);
  ref.onDispose(() => queue.dispose());
  return queue;
});

final activeDownloadsProvider = StreamProvider<List<DownloadTask>>((ref) {
  final queue = ref.watch(downloadQueueProvider);
  return queue.onDownloadsChanged;
});

class DownloadQueue {
  final DownloadRepository _repository;
  final HttpClient _httpClient;
  final StreamController<List<DownloadTask>> _downloadsController =
      StreamController<List<DownloadTask>>.broadcast();
  final StreamController<DownloadTask> _progressController =
      StreamController<DownloadTask>.broadcast();

  final List<DownloadTask> _pendingQueue = [];
  final Map<String, DownloadTask> _tasks = {};
  List<DownloadTask> _latestTasks = [];
  int _maxConcurrent = 3;
  int _runningCount = 0;

  DownloadQueue(this._repository, this._httpClient) {
    _downloadsController.add([]);
  }

  Stream<List<DownloadTask>> get onDownloadsChanged async* {
    yield _latestTasks;
    yield* _downloadsController.stream;
  }

  Stream<DownloadTask> get onProgress => _progressController.stream;

  void setMaxConcurrent(int max) {
    _maxConcurrent = max;
    _processQueue();
  }

  Future<void> enqueue({
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  }) async {
    final task = await _repository.startDownload(
      bookId: bookId,
      bookTitle: bookTitle,
      format: format,
      sourceUrl: sourceUrl,
    );

    _tasks[task.id] = task;
    _pendingQueue.add(task);
    _emitUpdate();
    _processQueue();
  }

  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.running) return;

    final paused = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.paused,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );

    _tasks[taskId] = paused;
    _runningCount--;
    await _repository.updateStatus(taskId, DownloadStatus.paused);
    _emitUpdate();
    _processQueue();
  }

  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;

    final queued = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.queued,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );

    _tasks[taskId] = queued;
    _pendingQueue.add(queued);
    await _repository.updateStatus(taskId, DownloadStatus.queued);
    _emitUpdate();
    _processQueue();
  }

  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.running) {
      _runningCount--;
    }

    final canceled = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.canceled,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );

    _tasks[taskId] = canceled;
    _pendingQueue.removeWhere((t) => t.id == taskId);
    await _repository.cancelDownload(taskId);
    _emitUpdate();
    _processQueue();
  }

  Future<void> remove(String taskId) async {
    _tasks.remove(taskId);
    _pendingQueue.removeWhere((t) => t.id == taskId);
    await _repository.removeDownload(taskId);
    _emitUpdate();
  }

  void _processQueue() {
    while (_runningCount < _maxConcurrent && _pendingQueue.isNotEmpty) {
      final next = _pendingQueue.removeAt(0);
      if (next.status == DownloadStatus.queued) {
        unawaited(_startTask(next));
      }
    }
  }

  Future<void> _startTask(DownloadTask task) async {
    _runningCount++;
    final running = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.running,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );
    _tasks[task.id] = running;
    await _repository.updateStatus(task.id, DownloadStatus.running);
    _emitUpdate();

    try {
      final targetPath = task.targetPath;
      if (targetPath == null) {
        throw StateError('No target path for download ${task.id}');
      }
      await _httpClient.download(
        task.sourceUrl,
        targetPath,
        onProgress: (int received, int total) {
          final updated = DownloadTask(
            id: task.id,
            bookId: task.bookId,
            format: task.format,
            sourceUrl: task.sourceUrl,
            targetPath: task.targetPath,
            status: DownloadStatus.running,
            downloadedBytes: received,
            totalBytes: total,
          );
          _tasks[task.id] = updated;
          _progressController.add(updated);

          unawaited(_repository.updateProgress(task.id, received, total));
        },
      );

      final latest = _tasks[task.id] ?? task;
      final completed = DownloadTask(
        id: task.id,
        bookId: task.bookId,
        format: task.format,
        sourceUrl: task.sourceUrl,
        targetPath: task.targetPath,
        status: DownloadStatus.completed,
        downloadedBytes: latest.totalBytes ?? latest.downloadedBytes ?? 0,
        totalBytes: latest.totalBytes ?? latest.downloadedBytes ?? 0,
      );
      _tasks[task.id] = completed;
      await _repository.updateStatus(task.id, DownloadStatus.completed);
    } on Object {
      final failed = DownloadTask(
        id: task.id,
        bookId: task.bookId,
        format: task.format,
        sourceUrl: task.sourceUrl,
        targetPath: task.targetPath,
        status: DownloadStatus.failed,
        downloadedBytes: task.downloadedBytes,
        totalBytes: task.totalBytes,
      );
      _tasks[task.id] = failed;
      await _repository.updateStatus(task.id, DownloadStatus.failed);
    } finally {
      _runningCount--;
      _emitUpdate();
      _processQueue();
    }
  }

  void _emitUpdate() {
    _latestTasks = _tasks.values.toList();
    _downloadsController.add(_latestTasks);
  }

  void dispose() {
    unawaited(_downloadsController.close());
    unawaited(_progressController.close());
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/http_client.dart';
import '../../../core/notifications/download_notification_service.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../data/download_repository.dart';
import '../domain/download_repository.dart';

final downloadQueueProvider = Provider<DownloadQueue>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  final httpClient = ref.watch(httpClientProvider);
  final notificationService = ref.watch(downloadNotificationServiceProvider);
  final queue = DownloadQueue(repository, httpClient, notificationService);
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
  final DownloadNotificationService _notificationService;
  final StreamController<List<DownloadTask>> _downloadsController =
      StreamController<List<DownloadTask>>.broadcast();
  final StreamController<DownloadTask> _progressController =
      StreamController<DownloadTask>.broadcast();

  final List<DownloadTask> _pendingQueue = [];
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, _SpeedTracker> _speedTrackers = {};
  final Map<String, Completer<void>> _cancelCompleters = {};
  final Set<String> _cancelledIds = {};
  final Map<String, int> _retryAttempts = {};
  List<DownloadTask> _latestTasks = [];
  int _maxConcurrent = 3;
  int _runningCount = 0;
  bool _disposed = false;
  static const int maxRetryAttempts = 3;

  DownloadQueue(
    this._repository,
    this._httpClient,
    this._notificationService,
  ) {
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

  Future<String> enqueue({
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  }) async {
    for (final existing in _tasks.values) {
      if (existing.bookId == bookId &&
          existing.format == format &&
          existing.status != DownloadStatus.canceled &&
          existing.status != DownloadStatus.failed) {
        return existing.id;
      }
    }

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
    return task.id;
  }

  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.running) return;

    final paused = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      bookTitle: task.bookTitle,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.paused,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );

    _tasks[taskId] = paused;
    _speedTrackers.remove(taskId);
    await _notificationService.cancel(taskId);
    await _repository.updateStatus(taskId, DownloadStatus.paused);
    _emitUpdate();
  }

  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;

    final queued = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      bookTitle: task.bookTitle,
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

    _cancelledIds.add(taskId);
    _cancelCompleters[taskId]?.complete();

    final canceled = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      bookTitle: task.bookTitle,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.canceled,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );

    _tasks[taskId] = canceled;
    _speedTrackers.remove(taskId);
    _retryAttempts.remove(taskId);
    _pendingQueue.removeWhere((t) => t.id == taskId);
    await _notificationService.cancel(taskId);
    await _repository.cancelDownload(taskId);
    _emitUpdate();
  }

  Future<void> remove(String taskId) async {
    _tasks.remove(taskId);
    _speedTrackers.remove(taskId);
    _retryAttempts.remove(taskId);
    _pendingQueue.removeWhere((t) => t.id == taskId);
    await _notificationService.cancel(taskId);
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
      bookTitle: task.bookTitle,
      format: task.format,
      sourceUrl: task.sourceUrl,
      targetPath: task.targetPath,
      status: DownloadStatus.running,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
    );
    _tasks[task.id] = running;
    _speedTrackers[task.id] = _SpeedTracker();
    await _repository.updateStatus(task.id, DownloadStatus.running);
    _emitUpdate();

    try {
      final targetPath = task.targetPath;
      if (targetPath == null) {
        throw StateError('No target path for download ${task.id}');
      }
      final cancelCompleter = Completer<void>();
      _cancelCompleters[task.id] = cancelCompleter;
      final onCancel = cancelCompleter.future;

      await _httpClient.download(
        task.sourceUrl,
        targetPath,
        onCancel: onCancel,
        onProgress: (int received, int total) {
          final speedTracker = _speedTrackers[task.id];
          final speed = speedTracker?.update(received) ?? 0;

          final updated = DownloadTask(
            id: task.id,
            bookId: task.bookId,
            bookTitle: task.bookTitle ?? '',

            format: task.format,
            sourceUrl: task.sourceUrl,
            targetPath: task.targetPath,
            status: DownloadStatus.running,
            downloadedBytes: received,
            totalBytes: total > 0 ? total : null,
          );
          _tasks[task.id] = updated;
          _progressController.add(updated);

          if (speedTracker != null && speedTracker.shouldNotify()) {
            unawaited(_repository.updateProgress(task.id, received, total));
            unawaited(
              _notificationService.showProgress(
                task: updated,
                speedBytesPerSec: speed,
              ),
            );
          }
        },
      );

      final latest = _tasks[task.id] ?? task;
      final completed = DownloadTask(
        id: task.id,
        bookId: task.bookId,
        bookTitle: task.bookTitle,
        format: task.format,
        sourceUrl: task.sourceUrl,
        targetPath: task.targetPath,
        status: DownloadStatus.completed,
        downloadedBytes: latest.totalBytes ?? latest.downloadedBytes ?? 0,
        totalBytes: latest.totalBytes ?? latest.downloadedBytes ?? 0,
      );
      _tasks[task.id] = completed;
      _speedTrackers.remove(task.id);
      _retryAttempts.remove(task.id);
      await _repository.updateStatus(task.id, DownloadStatus.completed);
      await _repository.registerInLibrary(
        bookId: task.bookId,
        bookTitle: task.bookTitle ?? '',
        format: task.format.name,
        filePath: task.targetPath ?? '',
      );
      await _notificationService.showCompleted(completed);
    } on Object {
      final isCancelled = _cancelledIds.contains(task.id);
      if (!isCancelled) {
        final attempts = _retryAttempts[task.id] ?? 0;
        if (attempts < maxRetryAttempts && !_disposed) {
          _retryAttempts[task.id] = attempts + 1;
          final delayMs = 1000 * (1 << attempts); // 1s, 2s, 4s
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          if (_cancelledIds.contains(task.id) || _disposed) {
            _retryAttempts.remove(task.id);
          } else {
            final retried = DownloadTask(
              id: task.id,
              bookId: task.bookId,
              bookTitle: task.bookTitle ?? '',
              format: task.format,
              sourceUrl: task.sourceUrl,
              targetPath: task.targetPath,
              status: DownloadStatus.queued,
              downloadedBytes: task.downloadedBytes,
              totalBytes: task.totalBytes,
            );
            _tasks[task.id] = retried;
            _pendingQueue.add(retried);
            _emitUpdate();
            return; // don't process as failed
          }
        }
      }
      _retryAttempts.remove(task.id);
      final status = isCancelled ? DownloadStatus.canceled : DownloadStatus.failed;
      final failed = DownloadTask(
        id: task.id,
        bookId: task.bookId,
        bookTitle: task.bookTitle,
        format: task.format,
        sourceUrl: task.sourceUrl,
        targetPath: task.targetPath,
        status: status,
        downloadedBytes: task.downloadedBytes,
        totalBytes: task.totalBytes,
      );
      _tasks[task.id] = failed;
      _speedTrackers.remove(task.id);
      await _repository.updateStatus(task.id, status);
      if (isCancelled) {
        await _notificationService.cancel(task.id);
      } else {
        await _notificationService.showFailed(failed, null);
      }
    } finally {
      _cancelCompleters.remove(task.id);
      _cancelledIds.remove(task.id);
      _runningCount--;
      _emitUpdate();
      _processQueue();
    }
  }

  void _emitUpdate() {
    if (_disposed) return;
    _latestTasks = _tasks.values.toList();
    _downloadsController.add(_latestTasks);
  }

  void dispose() {
    _disposed = true;
    for (final entry in _cancelCompleters.entries) {
      if (!entry.value.isCompleted) {
        _cancelledIds.add(entry.key);
        entry.value.complete();
      }
    }
    _cancelCompleters.clear();
    _tasks.clear();
    _speedTrackers.clear();
    _pendingQueue.clear();
    unawaited(_downloadsController.close());
    unawaited(_progressController.close());
  }
}

class _SpeedTracker {
  int _lastBytes = 0;
  int _lastTimestamp = 0;
  int _notificationCounter = 0;

  _SpeedTracker() {
    _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  double update(int currentBytes) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastTimestamp;
    if (elapsed <= 0) return 0;

    final deltaBytes = currentBytes - _lastBytes;
    final speed = deltaBytes * 1000.0 / elapsed;

    _lastBytes = currentBytes;
    _lastTimestamp = now;
    return speed;
  }

  bool shouldNotify() {
    _notificationCounter++;
    return _notificationCounter % 3 == 0;
  }
}

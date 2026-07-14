import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glibusta/features/downloads/data/download_listener.dart' show DownloadListener;

import '../../../core/logging/app_logger.dart';
import '../../../core/notifications/download_notification_service.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../library/data/book_import_service.dart';
import '../data/background_download_service.dart';
import '../data/download_repository.dart';
import '../domain/download_repository.dart';

final downloadQueueProvider = Provider<DownloadQueue>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  final bgDownload = ref.watch(backgroundDownloadServiceProvider);
  final notificationService = ref.watch(downloadNotificationServiceProvider);
  final bookImport = ref.watch(bookImportServiceProvider);
  final queue = DownloadQueue(repository, bgDownload, notificationService, bookImport);
  ref.onDispose(() => queue.dispose());
  return queue;
});

final activeDownloadsProvider = StreamProvider<List<DownloadTask>>((ref) {
  final queue = ref.watch(downloadQueueProvider);
  return queue.onDownloadsChanged;
});

/// Orchestrates downloads using background_downloader.
///
/// The actual download is delegated to [BackgroundDownloadService].
/// This class manages the in-memory state and emits UI updates.
class DownloadQueue {
  DownloadQueue(
    this._repository,
    this._bgDownload,
    this._notificationService,
    this._bookImport,
  );

  final DownloadRepository _repository;
  final BackgroundDownloadService _bgDownload;
  final DownloadNotificationService _notificationService;
  final BookImportService _bookImport;
  final _logger = AppLogger();

  final _downloadsController = StreamController<List<DownloadTask>>.broadcast();
  final _progressController = StreamController<DownloadTask>.broadcast();

  final Map<String, DownloadTask> _tasks = {};
  final Map<(String, BookFormat), Future<String>> _pendingEnqueues = {};
  List<DownloadTask> _latestTasks = [];
  Future<void>? _tasksHydration;
  bool _disposed = false;

  Stream<List<DownloadTask>> get onDownloadsChanged async* {
    await _hydrateTasks();
    if (_disposed) return;
    yield _latestTasks;
    yield* _downloadsController.stream;
  }

  Stream<DownloadTask> get onProgress => _progressController.stream;

  /// Initialize the background downloader. Call once at app start.
  void initialize() {
    _bgDownload.initialize();
  }

  Future<String> enqueue({
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  }) {
    final key = (bookId, format);
    final pending = _pendingEnqueues[key];
    if (pending != null) return pending;

    late final Future<String> enqueue;
    enqueue =
        _enqueue(
          bookId: bookId,
          bookTitle: bookTitle,
          format: format,
          sourceUrl: sourceUrl,
        ).whenComplete(() {
          _pendingEnqueues.remove(key)?.ignore();
        });
    _pendingEnqueues[key] = enqueue;
    return enqueue;
  }

  Future<String> _enqueue({
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  }) async {
    await _hydrateTasks();

    // Deduplicate: skip if same bookId+format is already active.
    for (final existing in _tasks.values) {
      if (existing.bookId == bookId && existing.format == format && _isActive(existing.status)) {
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
    _emitUpdate();

    // Enqueue in background_downloader.
    try {
      await _bgDownload.enqueue(
        taskId: task.id,
        bookId: bookId,
        bookTitle: bookTitle,
        format: format,
        sourceUrl: sourceUrl,
      );
    } on Object catch (error, stackTrace) {
      final failedTask = task.copyWith(status: DownloadStatus.failed);
      _tasks[task.id] = failedTask;
      _emitUpdate();
      try {
        await _repository.updateStatus(task.id, DownloadStatus.failed);
      } on Object catch (persistenceError, persistenceStackTrace) {
        _logger.warning(
          'Could not persist failed download ${task.id}: $persistenceError',
          name: 'DownloadQueue',
          error: persistenceError,
          st: persistenceStackTrace,
        );
      }
      _logger.warning(
        'Could not enqueue download ${task.id}: $error',
        name: 'DownloadQueue',
        error: error,
        st: stackTrace,
      );
      rethrow;
    }

    return task.id;
  }

  static bool _isActive(DownloadStatus status) =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.running ||
      status == DownloadStatus.paused;

  Future<void> _hydrateTasks() async {
    final hydration = _tasksHydration;
    if (hydration != null) return hydration;

    final load = _loadPersistedTasks();
    _tasksHydration = load;
    try {
      await load;
    } on Object {
      if (identical(_tasksHydration, load)) {
        _tasksHydration = null;
      }
      rethrow;
    }
  }

  Future<void> _loadPersistedTasks() async {
    final persistedTasks = await _repository.getAllDownloads();
    if (_disposed) return;
    for (final task in persistedTasks) {
      _tasks.putIfAbsent(task.id, () => task);
    }
    _latestTasks = _tasks.values.toList();
  }

  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.running) return;

    await _bgDownload.pause(taskId);
    await _repository.updateStatus(taskId, DownloadStatus.paused);
    _tasks[taskId] = task.copyWith(status: DownloadStatus.paused);
    _emitUpdate();
  }

  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;

    await _bgDownload.resume(taskId);
    await _repository.updateStatus(taskId, DownloadStatus.queued);
    _tasks[taskId] = task.copyWith(status: DownloadStatus.queued);
    _emitUpdate();
  }

  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    await _bgDownload.cancel(taskId);
    await _repository.cancelDownload(taskId);
    _tasks[taskId] = task.copyWith(status: DownloadStatus.canceled);
    _bgDownload.removeTask(taskId);
    _emitUpdate();
  }

  Future<void> remove(String taskId) async {
    _tasks.remove(taskId);
    _bgDownload.removeTask(taskId);
    await _repository.removeDownload(taskId);
    _emitUpdate();
  }

  /// Called by [DownloadListener] when a download completes.
  /// Runs the full BookImportService pipeline.
  Future<void> onDownloadComplete(String taskId) async {
    var task = _tasks[taskId];

    // After restart, _tasks is empty. Load from DB.
    if (task == null) {
      final dbTask = await _repository.getDownloadById(taskId);
      if (dbTask == null) {
        _logger.warning(
          'onDownloadComplete: taskId $taskId not found in DB',
          name: 'DownloadQueue',
        );
        return;
      }
      task = dbTask;
      _tasks[taskId] = task;
    }

    if (task.status == DownloadStatus.completed) return;

    _tasks[taskId] = task.copyWith(status: DownloadStatus.completed);
    _bgDownload.removeTask(taskId);
    _emitUpdate();

    unawaited(_notificationService.showCompleted(task));

    if (task.targetPath != null) {
      try {
        final result = await _bookImport.importFile(task.targetPath!);
        if (result.isSuccess) {
          _logger.info(
            'Book imported after download: ${result.title}',
            name: 'DownloadQueue',
          );
        } else if (result.isDuplicate) {
          _logger.info(
            'Downloaded book is duplicate: ${result.title}',
            name: 'DownloadQueue',
          );
        } else {
          _logger.warning(
            'Import failed after download: ${result.error}',
            name: 'DownloadQueue',
          );
        }
      } on Object catch (e) {
        _logger.warning(
          'Import error after download for $taskId: $e',
          name: 'DownloadQueue',
        );
      }
    }
  }

  /// Called by [DownloadListener] when a download status changes.
  void onStatusChanged(String taskId, DownloadStatus status) {
    final task = _tasks[taskId];
    if (task == null) return;

    _tasks[taskId] = task.copyWith(status: status);
    if (status == DownloadStatus.canceled || status == DownloadStatus.failed) {
      _bgDownload.removeTask(taskId);
    }
    _emitUpdate();

    // Show notification for terminal states.
    if (status == DownloadStatus.failed) {
      unawaited(_notificationService.showFailed(task, null));
    } else if (status == DownloadStatus.canceled) {
      unawaited(_notificationService.cancel(taskId));
    }
  }

  /// Called by [DownloadListener] when progress updates.
  void onProgressChanged(String taskId, int downloaded, int total) {
    final task = _tasks[taskId];
    if (task == null) return;

    final updated = task.copyWith(
      downloadedBytes: downloaded,
      totalBytes: total,
    );
    _tasks[taskId] = updated;
    _progressController.add(updated);
    _emitUpdate();
  }

  void _emitUpdate() {
    if (_disposed) return;
    _latestTasks = _tasks.values.toList();
    _downloadsController.add(_latestTasks);
  }

  void dispose() {
    _disposed = true;
    _tasks.clear();
    unawaited(_downloadsController.close());
    unawaited(_progressController.close());
  }
}

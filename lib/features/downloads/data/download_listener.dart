import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../shared/models/download_task.dart';
import '../domain/download_repository.dart';
import '../presentation/download_queue.dart';
import 'background_download_service.dart';
import 'download_repository.dart';

final downloadListenerProvider = Provider<DownloadListener>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  final queue = ref.watch(downloadQueueProvider);
  final listener = DownloadListener(repository, queue);
  ref.onDispose(() => listener.dispose());
  return listener;
});

/// Listens to [bd.FileDownloader] updates and maps them to
/// [DownloadRepository] state changes + [DownloadQueue] callbacks.
class DownloadListener {
  DownloadListener(this._repository, this._queue);

  final DownloadRepository _repository;
  final DownloadQueue _queue;
  final _logger = AppLogger();
  StreamSubscription<bd.TaskUpdate>? _subscription;

  void startListening() {
    unawaited(_subscription?.cancel());
    _subscription = bd.FileDownloader().updates.listen(_onUpdate);
    _logger.info('DownloadListener started', name: 'DownloadListener');
    unawaited(_recoverStaleDownloads());
  }

  /// Recover downloads stuck in running/queued status from a previous app session.
  /// background_downloader does not replay completed events on restart.
  Future<void> _recoverStaleDownloads() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    try {
      final allTasks = await _repository.getAllDownloads();
      final stale = allTasks
          .where((t) => t.status == DownloadStatus.running || t.status == DownloadStatus.queued)
          .toList();
      if (stale.isEmpty) return;
      _logger.info(
        'Recovering ${stale.length} stale download(s)',
        name: 'DownloadListener',
      );
      for (final task in stale) {
        final path = task.targetPath;
        if (path != null && await File(path).exists()) {
          _logger.info(
            'Stale download file exists, completing: ${task.id}',
            name: 'DownloadListener',
          );
          await _repository.updateStatus(task.id, DownloadStatus.completed);
          unawaited(_queue.onDownloadComplete(task.id));
        } else {
          _logger.warning(
            'Stale download file missing, marking failed: ${task.id}',
            name: 'DownloadListener',
          );
          await _repository.updateStatus(task.id, DownloadStatus.failed);
          _queue.onStatusChanged(task.id, DownloadStatus.failed);
        }
      }
    } on Object catch (e) {
      _logger.warning('Stale recovery failed: $e', name: 'DownloadListener');
    }
  }

  Future<void> _onUpdate(bd.TaskUpdate update) async {
    switch (update) {
      case bd.TaskStatusUpdate():
        await _onStatusUpdate(update);
      case bd.TaskProgressUpdate():
        await _onProgressUpdate(update);
    }
  }

  Future<void> _onStatusUpdate(bd.TaskStatusUpdate update) async {
    final taskId = BackgroundDownloadService.extractTaskId(update.task);
    if (taskId == null) return;

    switch (update.status) {
      case bd.TaskStatus.complete:
        _logger.info('Download complete: $taskId', name: 'DownloadListener');
        unawaited(_repository.updateStatus(taskId, DownloadStatus.completed));
        unawaited(_queue.onDownloadComplete(taskId));

      case bd.TaskStatus.canceled:
        _logger.info('Download canceled: $taskId', name: 'DownloadListener');
        unawaited(_repository.updateStatus(taskId, DownloadStatus.canceled));
        _queue.onStatusChanged(taskId, DownloadStatus.canceled);

      case bd.TaskStatus.failed:
        _logger.warning('Download failed: $taskId', name: 'DownloadListener');
        unawaited(_repository.updateStatus(taskId, DownloadStatus.failed));
        _queue.onStatusChanged(taskId, DownloadStatus.failed);

      case bd.TaskStatus.paused:
        _logger.info('Download paused: $taskId', name: 'DownloadListener');
        unawaited(_repository.updateStatus(taskId, DownloadStatus.paused));
        _queue.onStatusChanged(taskId, DownloadStatus.paused);

      case bd.TaskStatus.enqueued:
        _logger.info('Download enqueued: $taskId', name: 'DownloadListener');
        unawaited(_repository.updateStatus(taskId, DownloadStatus.queued));
        _queue.onStatusChanged(taskId, DownloadStatus.queued);

      case bd.TaskStatus.running:
        unawaited(_repository.updateStatus(taskId, DownloadStatus.running));
        _queue.onStatusChanged(taskId, DownloadStatus.running);

      case bd.TaskStatus.waitingToRetry:
        _logger.info('Download retrying: $taskId', name: 'DownloadListener');

      case bd.TaskStatus.notFound:
        _logger.warning('Download task not found: $taskId', name: 'DownloadListener');
    }
  }

  Future<void> _onProgressUpdate(bd.TaskProgressUpdate update) async {
    final taskId = BackgroundDownloadService.extractTaskId(update.task);
    if (taskId == null) return;

    final totalBytes = update.expectedFileSize > 0 ? update.expectedFileSize : 0;
    final downloadedBytes = (update.progress * totalBytes).round();

    unawaited(_repository.updateProgress(taskId, downloadedBytes, totalBytes));
    _queue.onProgressChanged(taskId, downloadedBytes, totalBytes);
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../domain/download_repository.dart';
import 'download_repository.dart';

String sanitizeBookId(String id) {
  var s = id.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  while (s.startsWith('.')) {
    s = s.substring(1);
  }
  s = s.trim();
  if (s.isEmpty) s = 'unnamed';
  if (s.length > 200) s = s.substring(0, 200);
  return s;
}

final backgroundDownloadServiceProvider = Provider<BackgroundDownloadService>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  return BackgroundDownloadService(repository);
});

/// Wraps [bd.FileDownloader] from background_downloader to handle
/// enqueue/pause/resume/cancel with proper model mapping.
class BackgroundDownloadService {
  BackgroundDownloadService(this._repository);

  // ignore: unused_field // ponytail: kept for future use (book metadata)
  final DownloadRepository _repository;
  final _logger = AppLogger();
  final _fileDownloader = bd.FileDownloader();

  /// Map from our taskId → background_downloader task.
  final Map<String, bd.DownloadTask> _bdTasks = {};

  /// Enqueue a download via background_downloader.
  ///
  /// Returns the taskId (same as our DownloadTask.id).
  Future<String> enqueue({
    required String taskId,
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  }) async {
    final fileName = '${sanitizeBookId(bookId)}.${format.name}';

    final bdTask = bd.DownloadTask(
      url: sourceUrl,
      filename: fileName,
      baseDirectory: bd.BaseDirectory.root,
      directory: '/storage/emulated/0/Download/Glibusta',
      updates: bd.Updates.statusAndProgress,
      allowPause: true,
      retries: 3,
      metaData: jsonEncode({
        'taskId': taskId,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'format': format.name,
      }),
    );

    _bdTasks[taskId] = bdTask;
    await _fileDownloader.enqueue(bdTask);
    _logger.info('Enqueued download: $taskId (${format.name})', name: 'BackgroundDownload');
    return taskId;
  }

  /// Pause a running download.
  Future<void> pause(String taskId) async {
    final bdTask = _bdTasks[taskId];
    if (bdTask == null) return;
    await _fileDownloader.pause(bdTask);
    _logger.info('Paused download: $taskId', name: 'BackgroundDownload');
  }

  /// Resume a paused download.
  Future<void> resume(String taskId) async {
    final bdTask = _bdTasks[taskId];
    if (bdTask == null) return;
    await _fileDownloader.resume(bdTask);
    _logger.info('Resumed download: $taskId', name: 'BackgroundDownload');
  }

  /// Cancel a download.
  Future<void> cancel(String taskId) async {
    final bdTask = _bdTasks[taskId];
    if (bdTask == null) return;
    await _fileDownloader.cancel(bdTask);
    _bdTasks.remove(taskId);
    _logger.info('Cancelled download: $taskId', name: 'BackgroundDownload');
  }

  /// Remove a task from tracking.
  void removeTask(String taskId) {
    _bdTasks.remove(taskId);
  }

  /// Initialize the file downloader. Call once at app start.
  void initialize() {
    unawaited(_fileDownloader.start());
    _logger.info('BackgroundDownloadService initialized', name: 'BackgroundDownload');
  }

  /// Extract taskId from a background_downloader [bd.Task] metadata.
  static String? extractTaskId(bd.Task bdTask) {
    try {
      final dynamic metaData = bdTask.metaData;
      final String metaStr = metaData is String ? metaData : '{}';
      final meta = jsonDecode(metaStr) as Map<String, dynamic>;
      return meta['taskId'] as String?;
    } on Object {
      return null;
    }
  }

  /// Extract book metadata from a background_downloader [bd.Task].
  static Map<String, String?> extractBookMeta(bd.Task bdTask) {
    try {
      final dynamic metaData = bdTask.metaData;
      final String metaStr = metaData is String ? metaData : '{}';
      final meta = jsonDecode(metaStr) as Map<String, dynamic>;
      return {
        'bookId': meta['bookId'] as String?,
        'bookTitle': meta['bookTitle'] as String?,
        'format': meta['format'] as String?,
      };
    } on Object {
      return {};
    }
  }
}

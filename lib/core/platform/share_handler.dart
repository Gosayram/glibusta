import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/library/data/book_import_service.dart';
import '../../features/reader/data/parsers/format_detector.dart';
import '../logging/app_logger.dart';
import '../services/background_task_provider.dart';
import '../services/task_queue_service.dart';
import '../storage/storage_bridge_impl.dart';

typedef SharedBookImporter = Future<ImportResult> Function(String filePath);
typedef SharedUriCache = Future<String?> Function(String uri);

class ShareHandler {
  ShareHandler({
    required TaskQueueService taskQueue,
    SharedUriCache? cacheSharedUri,
    @visibleForTesting bool forceEnable = false,
  }) : _taskQueue = taskQueue,
       _cacheSharedUri = cacheSharedUri ?? StorageBridgeImpl().copyToCache,
       _forceEnable = forceEnable;

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  var _subscriptionGeneration = 0;
  final TaskQueueService _taskQueue;
  final SharedUriCache _cacheSharedUri;
  final bool _forceEnable;
  final _logger = AppLogger();

  void init(BuildContext context, SharedBookImporter importFile) {
    // ponytail: receive_sharing_intent has no macOS impl — receiving shared
    // files is an Android/iOS-only feature. Tests pass forceEnable to exercise
    // the platform-independent logic with a mocked plugin.
    if (!_forceEnable && Platform.isMacOS) return;
    _logger.info('ShareHandler initialized', name: 'Share');
    final generation = ++_subscriptionGeneration;
    final previousSubscription = _subscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (_subscriptionGeneration != generation || !context.mounted) return;
        _handleSharedFiles(files, context, importFile, generation);
      },
      onError: (Object e, StackTrace st) {
        _logger.warning(
          'Share intent stream error: $e',
          name: 'Share',
          error: e,
          st: st,
        );
      },
    );

    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then(
        (files) {
          // reset() may clear a plugin-owned list synchronously. Keep the
          // cold-start payload alive while acknowledging that intent.
          final sharedFiles = List<SharedMediaFile>.of(files);
          unawaited(_resetInitialMedia());
          if (_subscriptionGeneration != generation || !context.mounted) return;
          _handleSharedFiles(sharedFiles, context, importFile, generation);
        },
        onError: (Object e, StackTrace st) {
          _logger.warning(
            'Initial share intent read failed: $e',
            name: 'Share',
            error: e,
            st: st,
          );
        },
      ),
    );
  }

  Future<void> _resetInitialMedia() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Initial share intent reset failed: $error',
        name: 'Share',
        error: error,
        st: stackTrace,
      );
    }
  }

  void _handleSharedFiles(
    List<SharedMediaFile> files,
    BuildContext context,
    SharedBookImporter importFile,
    int generation,
  ) {
    _logger.info('Shared ${files.length} files', name: 'Share');
    for (final file in files) {
      unawaited(_importSharedFile(file, context, importFile, generation));
    }
  }

  Future<void> _importSharedFile(
    SharedMediaFile file,
    BuildContext context,
    SharedBookImporter importFile,
    int generation,
  ) async {
    var filePath = file.path;
    try {
      if (!context.mounted || _subscriptionGeneration != generation) return;
      if (filePath.startsWith('content://')) {
        final cachedPath = await _cacheSharedUri(filePath);
        if (!context.mounted || _subscriptionGeneration != generation) return;
        if (cachedPath == null) {
          _logger.warning('Could not cache shared URI: $filePath', name: 'Share');
          if (context.mounted) {
            await SmartDialog.showToast('Не удалось открыть отправленный файл');
          }
          return;
        }
        filePath = cachedPath;
      }

      final ext = filePath.split('.').last.toLowerCase();
      if (!importableExtensions.contains(ext)) {
        _logger.info('Skipping unsupported: $filePath', name: 'Share');
        return;
      }

      if (!context.mounted || _subscriptionGeneration != generation) return;
      final result = await _taskQueue.run<ImportResult>(
        type: BackgroundTaskType.import,
        message: 'Импорт: ${filePath.split('/').last}',
        task: () => importFile(filePath),
      );
      if (!context.mounted || _subscriptionGeneration != generation) return;
      await SmartDialog.showToast(
        result.isSuccess
            ? 'Импортировано: ${result.title}'
            : result.isDuplicate
            ? 'Дубликат: ${result.title}'
            : 'Ошибка: ${result.error}',
      );
    } on Object catch (e, st) {
      _logger.warning(
        'Shared file import failed: $filePath: $e',
        name: 'Share',
        error: e,
        st: st,
      );
      if (!context.mounted || _subscriptionGeneration != generation) return;
      final fileName = filePath.split(RegExp(r'[\\/]')).last;
      await SmartDialog.showToast('Не удалось импортировать: $fileName');
    }
  }

  void dispose() {
    _subscriptionGeneration++;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

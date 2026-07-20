import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/library/data/book_import_service.dart';
import '../../features/reader/data/parsers/format_detector.dart';
import '../logging/app_logger.dart';
import '../storage/storage_bridge_impl.dart';

typedef SharedBookImporter = Future<ImportResult> Function(String filePath);
typedef SharedUriCache = Future<String?> Function(String uri);

class ShareHandler {
  ShareHandler({SharedUriCache? cacheSharedUri})
    : _cacheSharedUri = cacheSharedUri ?? StorageBridgeImpl().copyToCache;

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final SharedUriCache _cacheSharedUri;
  final _logger = AppLogger();

  void init(BuildContext context, SharedBookImporter importFile) {
    _logger.info('ShareHandler initialized', name: 'Share');
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (!context.mounted) return;
        _handleSharedFiles(files, context, importFile);
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
          if (!context.mounted) return;
          _handleSharedFiles(sharedFiles, context, importFile);
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
  ) {
    _logger.info('Shared ${files.length} files', name: 'Share');
    for (final file in files) {
      unawaited(_importSharedFile(file, context, importFile));
    }
  }

  Future<void> _importSharedFile(
    SharedMediaFile file,
    BuildContext context,
    SharedBookImporter importFile,
  ) async {
    var filePath = file.path;
    try {
      if (filePath.startsWith('content://')) {
        final cachedPath = await _cacheSharedUri(filePath);
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

      final result = await importFile(filePath);
      if (!context.mounted) return;
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
      if (!context.mounted) return;
      final fileName = filePath.split(RegExp(r'[\\/]')).last;
      await SmartDialog.showToast('Не удалось импортировать: $fileName');
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

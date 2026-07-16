import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/library/data/book_import_service.dart';
import '../../features/reader/data/parsers/format_detector.dart';
import '../logging/app_logger.dart';

typedef SharedBookImporter = Future<ImportResult> Function(String filePath);

class ShareHandler {
  StreamSubscription<List<SharedMediaFile>>? _subscription;
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
          unawaited(_resetInitialMedia());
          if (!context.mounted) return;
          _handleSharedFiles(files, context, importFile);
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
      final ext = file.path.split('.').last.toLowerCase();
      if (!importableExtensions.contains(ext)) {
        _logger.info('Skipping unsupported: ${file.path}', name: 'Share');
        continue;
      }

      unawaited(
        importFile(file.path)
            .then((result) {
              if (!context.mounted) return;
              unawaited(
                SmartDialog.showToast(
                  result.isSuccess
                      ? 'Импортировано: ${result.title}'
                      : result.isDuplicate
                      ? 'Дубликат: ${result.title}'
                      : 'Ошибка: ${result.error}',
                ),
              );
            })
            .catchError((Object e, StackTrace st) {
              _logger.warning(
                'Shared file import failed: ${file.path}: $e',
                name: 'Share',
                error: e,
                st: st,
              );
              if (!context.mounted) return;
              final fileName = file.path.split(RegExp(r'[\\/]')).last;
              unawaited(SmartDialog.showToast('Не удалось импортировать: $fileName'));
            }),
      );
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

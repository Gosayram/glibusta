import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/library/data/book_import_service.dart';
import '../logging/app_logger.dart';

class ShareHandler {
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final _logger = AppLogger();

  void init(BuildContext context, BookImportService importService) {
    _logger.info('ShareHandler initialized', name: 'Share');
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (!context.mounted) return;
        _handleSharedFiles(files, context, importService);
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
          if (!context.mounted) return;
          _handleSharedFiles(files, context, importService);
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

  void _handleSharedFiles(
    List<SharedMediaFile> files,
    BuildContext context,
    BookImportService importService,
  ) {
    _logger.info('Shared ${files.length} files', name: 'Share');
    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      if (![
        'epub',
        'fb2',
        'zip',
        'txt',
        'rtf',
        'mobi',
        'azw',
        'azw3',
        'prc',
        'djvu',
        'djv',
      ].contains(ext)) {
        _logger.info('Skipping unsupported: ${file.path}', name: 'Share');
        continue;
      }

      unawaited(
        importService
            .importFile(file.path)
            .then((result) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.isSuccess
                        ? 'Импортировано: ${result.title}'
                        : result.isDuplicate
                        ? 'Дубликат: ${result.title}'
                        : 'Ошибка: ${result.error}',
                  ),
                  duration: const Duration(seconds: 2),
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
            }),
      );
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

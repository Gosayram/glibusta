import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/library/data/book_import_service.dart';

class ShareHandler {
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  void init(BuildContext context, BookImportService importService) {
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (!context.mounted) return;
        _handleSharedFiles(files, context, importService);
      },
      onError: (Object e) {
        // Share intent stream error — non-critical
      },
    );

    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then(
        (files) {
          if (!context.mounted) return;
          _handleSharedFiles(files, context, importService);
        },
      ),
    );
  }

  void _handleSharedFiles(
    List<SharedMediaFile> files,
    BuildContext context,
    BookImportService importService,
  ) {
    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      if (!['epub', 'fb2', 'txt'].contains(ext)) continue;

      unawaited(
        importService.importFile(file.path).then((result) {
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
        }),
      );
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

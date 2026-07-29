import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_duration.dart';
import 'reader_controller.dart';

String _displayFileName(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final lastSlash = normalized.lastIndexOf('/');
  return lastSlash >= 0 ? normalized.substring(lastSlash + 1) : normalized;
}

/// Announces the reader failure once while keeping recovery controls separate.
class ReaderErrorSummary extends StatelessWidget {
  const ReaderErrorSummary({
    super.key,
    required this.kind,
    required this.message,
  });

  final ReaderErrorKind kind;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      label: '${kind.defaultTitle}. $message',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            kind.defaultTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class ReaderErrorPanel extends StatelessWidget {
  final ReaderController controller;
  final ReaderState readerState;
  final String bookId;
  final VoidCallback onDeleteFile;
  final VoidCallback onDeleteFromLibrary;

  const ReaderErrorPanel({
    super.key,
    required this.controller,
    required this.readerState,
    required this.bookId,
    required this.onDeleteFile,
    required this.onDeleteFromLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final kind = readerState.errorKind ?? ReaderErrorKind.unknown;
    final showCacheButton = kind != ReaderErrorKind.bookMissing;
    final showDeleteButton =
        readerState.errorFilePath != null && kind != ReaderErrorKind.bookMissing;

    return AnimatedTheme(
      data: Theme.of(context),
      duration: AppDuration.readerThemeTransition,
      curve: Curves.easeOutCubic,
      child: Scaffold(
        appBar: AppBar(title: const Text('Читалка')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReaderErrorSummary(
                      kind: kind,
                      message: readerState.errorMessage!,
                    ),
                    if (readerState.errorFilePath != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (readerState.errorFormat != null)
                              Text(
                                'Формат: ${readerState.errorFormat}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            if (readerState.errorFileSize != null)
                              Text(
                                'Размер: ${(readerState.errorFileSize! / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(fontSize: 13),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Файл: ${_displayFileName(readerState.errorFilePath!)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => controller.loadBook(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                        if (showCacheButton)
                          OutlinedButton.icon(
                            onPressed: () async {
                              await controller.clearCacheAndReload();
                              if (!context.mounted) return;
                              unawaited(SmartDialog.showToast('Кеш очищен'));
                            },
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('Очистить кеш'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () {
                            controller.copyDiagnostics();
                            unawaited(SmartDialog.showToast('Диагностика скопирована'));
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Копировать диагностику'),
                        ),
                        if (showDeleteButton)
                          OutlinedButton.icon(
                            onPressed: onDeleteFile,
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text(
                              'Удалить файл',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        if (showDeleteButton)
                          OutlinedButton.icon(
                            onPressed: onDeleteFromLibrary,
                            icon: const Icon(Icons.library_books_outlined, color: Colors.red),
                            label: const Text(
                              'Удалить из библиотеки',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        if (readerState.errorFilePath != null)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final file = File(readerState.errorFilePath!);
                              if (!await file.exists()) return;
                              final uri = Uri.file(readerState.errorFilePath!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Открыть в другом приложении'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

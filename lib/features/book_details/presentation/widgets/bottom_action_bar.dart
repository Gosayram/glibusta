import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formats/format_capability.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/download_task.dart';
import '../../../downloads/presentation/download_queue.dart';
import '../../../search/data/composite_source.dart';
import '../book_details_providers.dart';
import 'format_selection_sheet.dart';

class BottomActionBar extends ConsumerWidget {
  final Book book;
  final BookDetails details;

  const BottomActionBar({super.key, required this.book, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadStateAsync = ref.watch(bookDownloadStateProvider(book.id));
    final downloadState = downloadStateAsync.value ?? BookDownloadState.notDownloaded;
    final isDownloading = downloadState == BookDownloadState.downloading;
    final isDownloaded = downloadState == BookDownloadState.downloaded;
    final hasFormats = details.availableFormats.isNotEmpty;
    final capService = const FormatCapabilityService();
    final bestFormat = book.availableFormats.isNotEmpty
        ? book.availableFormats.first
        : BookFormat.unknown;
    final isDocumentOnly = capService.isDocumentOnly(bestFormat);
    final readLabel = isDocumentOnly ? 'Документ' : 'Читать';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => unawaited(context.push('/reader/${book.id}')),
                icon: Icon(isDocumentOnly ? Icons.description : Icons.play_arrow),
                label: Text(readLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isDownloaded
                  ? OutlinedButton.icon(
                      onPressed: () => unawaited(context.push('/reader/${book.id}')),
                      icon: Icon(isDocumentOnly ? Icons.description : Icons.play_arrow),
                      label: Text(isDocumentOnly ? 'Открыть документ' : 'Открыть'),
                    )
                  : OutlinedButton.icon(
                      onPressed: hasFormats && !isDownloading
                          ? () => _startDownload(context, ref, book, details)
                          : null,
                      icon: isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(isDownloading ? 'Загрузка...' : 'Скачать'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref,
    Book book,
    BookDetails details,
  ) async {
    final formats = details.availableFormats;
    if (formats.isEmpty) return;

    final selectedFormat = await showModalBottomSheet<BookFormat>(
      context: context,
      builder: (context) => FormatSelectionSheet(
        bookTitle: book.title,
        formats: formats,
      ),
    );

    if (selectedFormat == null || !context.mounted) return;

    final source = ref.read(bookSourceProvider);
    final queue = ref.read(downloadQueueProvider);

    try {
      final url = await source.getDownloadUrl(book.id, selectedFormat);
      await queue.enqueue(
        bookId: book.id,
        bookTitle: book.title,
        format: selectedFormat,
        sourceUrl: url,
      );
      ref.invalidate(bookDownloadStateProvider(book.id));
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Загрузка ${book.title} (${selectedFormat.name})'));
      }
    } on Object catch (e) {
      AppLogger().severe('Download failed: $e', name: 'BookDetails', error: e);
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Ошибка загрузки'));
      }
    }
  }
}

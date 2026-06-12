import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fonts/font_download_service.dart';
import 'font_download_service_provider.dart';

final fontListProvider = FutureProvider<List<DownloadableFont>>((ref) async {
  final service = ref.watch(fontDownloadServiceProvider);
  return service.getFonts();
});

class FontDownloadScreen extends ConsumerStatefulWidget {
  const FontDownloadScreen({super.key});

  @override
  ConsumerState<FontDownloadScreen> createState() => _FontDownloadScreenState();
}

class _FontDownloadScreenState extends ConsumerState<FontDownloadScreen> {
  final Map<String, double> _progress = {};
  final Map<String, bool> _downloading = {};

  @override
  Widget build(BuildContext context) {
    final fontsAsync = ref.watch(fontListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шрифты'),
      ),
      body: fontsAsync.when(
        data: (fonts) {
          if (fonts.isEmpty) {
            return const Center(child: Text('Нет доступных шрифтов'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fonts.length,
            itemBuilder: (context, index) {
              final font = fonts[index];
              return _FontTile(
                font: font,
                progress: _progress[font.id],
                isDownloading: _downloading[font.id] ?? false,
                onDownload: () => _downloadFont(font),
                onDelete: () => _deleteFont(font),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }

  Future<void> _downloadFont(DownloadableFont font) async {
    setState(() {
      _downloading[font.id] = true;
      _progress[font.id] = 0;
    });

    final service = ref.read(fontDownloadServiceProvider);
    await service.downloadFont(
      font,
      onProgress: (received, total) {
        if (total > 0) {
          setState(() {
            _progress[font.id] = received / total;
          });
        }
      },
    );

    setState(() {
      _downloading[font.id] = false;
      _progress.remove(font.id);
    });

    ref.invalidate(fontListProvider);
  }

  Future<void> _deleteFont(DownloadableFont font) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить шрифт?'),
        content: Text('Шрифт "${font.name}" будет удалён.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = ref.read(fontDownloadServiceProvider);
      await service.deleteFont(font);
      ref.invalidate(fontListProvider);
    }
  }
}

class _FontTile extends StatelessWidget {
  final DownloadableFont font;
  final double? progress;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _FontTile({
    required this.font,
    this.progress,
    required this.isDownloading,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.font_download,
                  color: font.isDownloaded
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        font.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        font.family,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (font.isDownloaded)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onDelete,
                  )
                else if (isDownloading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2,
                    ),
                  )
                else
                  FilledButton.tonal(
                    onPressed: onDownload,
                    child: const Text('Скачать'),
                  ),
              ],
            ),
            if (isDownloading && progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text(
                '${(progress! * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            // Font preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Тёмные леса были полны тайн. Каждое дерево хранит свою историю.',
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

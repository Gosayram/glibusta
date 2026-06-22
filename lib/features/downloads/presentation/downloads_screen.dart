import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/widgets/error_state_widget.dart';
import 'download_queue.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(activeDownloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузки'),
        actions: [
          downloadsAsync.when(
            data: (List<DownloadTask> downloads) {
              final active = downloads
                  .where((DownloadTask d) => d.status == DownloadStatus.running)
                  .length;
              return active > 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text('$active активных'),
                      ),
                    )
                  : const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: downloadsAsync.when(
        data: (List<DownloadTask> downloads) {
          if (downloads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_done,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет загрузок',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Скачайте книги из каталога',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => context.push('/catalog'),
                    child: const Text('Перейти в каталог'),
                  ),
                ],
              ).animate().fadeIn(duration: 250.ms),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: downloads.length,
            itemBuilder: (BuildContext context, int index) {
              final task = downloads[index];
              return DownloadTile(task: task);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => ErrorStateWidget(
          message: 'Не удалось загрузить загрузки',
          details: e.toString(),
          onRetry: () => ref.invalidate(activeDownloadsProvider),
        ),
      ),
    );
  }
}

class DownloadTile extends ConsumerWidget {
  final DownloadTask task;

  const DownloadTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queue = ref.read(downloadQueueProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: task.status == DownloadStatus.completed && task.bookId.isNotEmpty
            ? () => context.push('/reader/${task.bookId}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _statusIcon(task.status),
                    size: 20,
                    color: _statusColor(context, task.status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.bookTitle ?? task.sourceUrl.split('/').last,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    task.format.name.toUpperCase(),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              if (task.status == DownloadStatus.running ||
                  task.status == DownloadStatus.paused) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.totalBytes != null && task.totalBytes! > 0
                      ? (task.downloadedBytes ?? 0) / task.totalBytes!
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatBytes(task.downloadedBytes ?? 0)} / ${formatBytes(task.totalBytes ?? 0)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (task.status == DownloadStatus.running)
                    IconButton(
                      icon: const Icon(Icons.pause, size: 20),
                      onPressed: () => queue.pause(task.id),
                    ),
                  if (task.status == DownloadStatus.paused)
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 20),
                      onPressed: () => queue.resume(task.id),
                    ),
                  if (task.status != DownloadStatus.canceled &&
                      task.status != DownloadStatus.completed)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => queue.cancel(task.id),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => queue.remove(task.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.queued => Icons.hourglass_empty,
      DownloadStatus.running => Icons.download,
      DownloadStatus.paused => Icons.pause,
      DownloadStatus.completed => Icons.check_circle,
      DownloadStatus.failed => Icons.error,
      DownloadStatus.canceled => Icons.cancel,
    };
  }

  Color _statusColor(BuildContext context, DownloadStatus status) {
    return switch (status) {
      DownloadStatus.queued => AppColors.warning,
      DownloadStatus.running => AppColors.info,
      DownloadStatus.paused => AppColors.warning,
      DownloadStatus.completed => AppColors.success,
      DownloadStatus.failed => AppColors.error,
      DownloadStatus.canceled => Theme.of(context).colorScheme.outline,
    };
  }
}

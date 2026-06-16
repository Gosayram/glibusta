import 'dart:async';

import 'package:flutter/material.dart';

import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';

class TableOfContentsSheet extends StatelessWidget {
  final NormalizedBookMetadata metadata;
  final int currentChapterIndex;
  final ValueChanged<ReaderPosition> onJumpToPosition;
  final Map<int, ReaderChapter> loadedChapters;
  final bool isDynamicallyLoading;

  const TableOfContentsSheet({
    super.key,
    required this.metadata,
    required this.currentChapterIndex,
    required this.onJumpToPosition,
    this.loadedChapters = const {},
    this.isDynamicallyLoading = false,
  });

  static void show(
    BuildContext context, {
    required NormalizedBookMetadata metadata,
    required int currentChapterIndex,
    required ValueChanged<ReaderPosition> onJumpToPosition,
    Map<int, ReaderChapter> loadedChapters = const {},
    bool isDynamicallyLoading = false,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => _TableOfContentsContent(
            metadata: metadata,
            currentChapterIndex: currentChapterIndex,
            onJumpToPosition: onJumpToPosition,
            scrollController: scrollController,
            loadedChapters: loadedChapters,
            isDynamicallyLoading: isDynamicallyLoading,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _TableOfContentsContent extends StatelessWidget {
  final NormalizedBookMetadata metadata;
  final int currentChapterIndex;
  final ValueChanged<ReaderPosition> onJumpToPosition;
  final ScrollController scrollController;
  final Map<int, ReaderChapter> loadedChapters;
  final bool isDynamicallyLoading;

  const _TableOfContentsContent({
    required this.metadata,
    required this.currentChapterIndex,
    required this.onJumpToPosition,
    required this.scrollController,
    this.loadedChapters = const {},
    this.isDynamicallyLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.table_chart_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Содержание',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${metadata.chapterCount} глав',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: metadata.chapterCount,
            itemBuilder: (context, index) {
              final title = index < metadata.chapterTitles.length
                  ? metadata.chapterTitles[index]
                  : '';
              final isActive = index == currentChapterIndex;
              final isLoaded = loadedChapters.containsKey(index);
              final isUnloaded = !isLoaded && isDynamicallyLoading;
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: isUnloaded
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                title: Text(
                  title.isNotEmpty ? title : 'Глава ${index + 1}',
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isUnloaded
                        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                subtitle: isUnloaded
                    ? Text(
                        'загрузка...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                dense: true,
                onTap: () {
                  Navigator.of(context).pop();
                  final progress = metadata.chapterCount <= 1
                      ? 0.0
                      : index / (metadata.chapterCount - 1);
                  onJumpToPosition(
                    ReaderPosition(
                      bookId: metadata.id,
                      chapterIndex: index,
                      paragraphIndex: 0,
                      progressPercent: progress,
                      updatedAt: DateTime.now(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

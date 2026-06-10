import 'dart:async';

import 'package:flutter/material.dart';

import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';

class TableOfContentsSheet extends StatelessWidget {
  final NormalizedBook book;
  final int currentChapterIndex;
  final ValueChanged<ReaderPosition> onJumpToPosition;

  const TableOfContentsSheet({
    super.key,
    required this.book,
    required this.currentChapterIndex,
    required this.onJumpToPosition,
  });

  static void show(
    BuildContext context, {
    required NormalizedBook book,
    required int currentChapterIndex,
    required ValueChanged<ReaderPosition> onJumpToPosition,
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
            book: book,
            currentChapterIndex: currentChapterIndex,
            onJumpToPosition: onJumpToPosition,
            scrollController: scrollController,
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
  final NormalizedBook book;
  final int currentChapterIndex;
  final ValueChanged<ReaderPosition> onJumpToPosition;
  final ScrollController scrollController;

  const _TableOfContentsContent({
    required this.book,
    required this.currentChapterIndex,
    required this.onJumpToPosition,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag handle
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
        // Title
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
                '${book.chapters.length} глав',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // Chapter list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: book.chapters.length,
            itemBuilder: (context, index) {
              final chapter = book.chapters[index];
              final isActive = index == currentChapterIndex;
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
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
                  chapter.title.isNotEmpty ? chapter.title : 'Глава ${index + 1}',
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                subtitle: Text(
                  '${chapter.blocks.length} абзацев',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                dense: true,
                onTap: () {
                  Navigator.of(context).pop();
                  final progress = book.chapters.length <= 1
                      ? 0.0
                      : index / (book.chapters.length - 1);
                  onJumpToPosition(
                    ReaderPosition(
                      bookId: book.id,
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

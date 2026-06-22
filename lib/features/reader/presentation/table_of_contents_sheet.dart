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

class _TocEntry {
  final int index;
  final String title;
  final int depth;
  final bool isGroup;
  final int groupId;

  const _TocEntry({
    required this.index,
    required this.title,
    required this.depth,
    required this.isGroup,
    required this.groupId,
  });
}

class _TableOfContentsContent extends StatefulWidget {
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
  State<_TableOfContentsContent> createState() => _TableOfContentsContentState();
}

class _TableOfContentsContentState extends State<_TableOfContentsContent> {
  final Set<int> _collapsedGroups = {};

  List<_TocEntry> _buildHierarchy() {
    final titles = widget.metadata.chapterTitles;
    final entries = <_TocEntry>[];
    final depthStack = <({int depth, int groupId, String title})>[];

    for (var i = 0; i < titles.length; i++) {
      final title = i < titles.length ? titles[i] : '';
      final depth = _detectDepth(title);

      while (depthStack.isNotEmpty && depthStack.last.depth >= depth) {
        depthStack.removeLast();
      }

      final groupId = depthStack.isNotEmpty ? depthStack.last.groupId : i;
      entries.add(
        _TocEntry(
          index: i,
          title: title,
          depth: depth,
          isGroup: false,
          groupId: groupId,
        ),
      );
      depthStack.add((depth: depth, groupId: i, title: title));
    }

    final childGroupIds = <int>{};
    for (final entry in entries) {
      if (entries.any((e) => e.groupId == entry.index && e.index != entry.index)) {
        childGroupIds.add(entry.index);
      }
    }

    return entries.map((e) {
      if (childGroupIds.contains(e.index)) {
        return _TocEntry(
          index: e.index,
          title: e.title,
          depth: e.depth,
          isGroup: true,
          groupId: e.groupId,
        );
      }
      return e;
    }).toList();
  }

  int _detectDepth(String title) {
    final trimmed = title.trim();
    final match = RegExp(r'^(\d+(?:[.\-]\d+)*)\s').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.split(RegExp(r'[.\-]')).length - 1;
    }
    if (trimmed.startsWith(RegExp(r'[IVX]+\s'))) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildHierarchy();
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
                '${widget.metadata.chapterCount} глав',
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
            controller: widget.scrollController,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final title = entry.title.isNotEmpty ? entry.title : 'Глава ${entry.index + 1}';
              final isActive = entry.index == widget.currentChapterIndex;
              final isGroup = entry.isGroup;
              final isCollapsed = _collapsedGroups.contains(entry.groupId);
              final isLoaded = widget.loadedChapters.containsKey(entry.index);
              final isUnloaded = !isLoaded && widget.isDynamicallyLoading;

              return ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16.0 + entry.depth * 16.0,
                ),
                leading: isGroup
                    ? GestureDetector(
                        onTap: () => setState(() {
                          if (isCollapsed) {
                            _collapsedGroups.remove(entry.groupId);
                          } else {
                            _collapsedGroups.add(entry.groupId);
                          }
                        }),
                        child: Icon(
                          isCollapsed ? Icons.chevron_right : Icons.expand_more,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      )
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: isUnloaded
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '${entry.index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isActive
                        ? FontWeight.bold
                        : isGroup
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: isGroup ? 14 : 13,
                    color: isUnloaded
                        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                subtitle: isActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: LinearProgressIndicator(
                          value: widget.metadata.chapterCount <= 1
                              ? 0.0
                              : (widget.currentChapterIndex / (widget.metadata.chapterCount - 1))
                                    .clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      )
                    : isUnloaded
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
                  final progress = widget.metadata.chapterCount <= 1
                      ? 0.0
                      : entry.index / (widget.metadata.chapterCount - 1);
                  widget.onJumpToPosition(
                    ReaderPosition(
                      bookId: widget.metadata.id,
                      chapterIndex: entry.index,
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

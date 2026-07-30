import 'dart:async';

import 'package:flutter/material.dart';

import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';
import 'toc_hierarchy.dart';

class TableOfContentsSheet extends StatelessWidget {
  final NormalizedBookMetadata metadata;
  final int currentChapterIndex;
  final double currentChapterProgress;
  final ValueChanged<ReaderPosition> onJumpToPosition;
  final Map<int, ReaderChapter> loadedChapters;
  final bool isDynamicallyLoading;

  const TableOfContentsSheet({
    super.key,
    required this.metadata,
    required this.currentChapterIndex,
    this.currentChapterProgress = 0.0,
    required this.onJumpToPosition,
    this.loadedChapters = const {},
    this.isDynamicallyLoading = false,
  });

  static void show(
    BuildContext context, {
    required NormalizedBookMetadata metadata,
    required int currentChapterIndex,
    double currentChapterProgress = 0.0,
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
            currentChapterProgress: currentChapterProgress,
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

class _TableOfContentsContent extends StatefulWidget {
  final NormalizedBookMetadata metadata;
  final int currentChapterIndex;
  final double currentChapterProgress;
  final ValueChanged<ReaderPosition> onJumpToPosition;
  final ScrollController scrollController;
  final Map<int, ReaderChapter> loadedChapters;
  final bool isDynamicallyLoading;

  const _TableOfContentsContent({
    required this.metadata,
    required this.currentChapterIndex,
    this.currentChapterProgress = 0.0,
    required this.onJumpToPosition,
    required this.scrollController,
    this.loadedChapters = const {},
    this.isDynamicallyLoading = false,
  });

  @override
  State<_TableOfContentsContent> createState() => _TableOfContentsContentState();
}

class _TableOfContentsContentState extends State<_TableOfContentsContent> {
  static const _estimatedEntryExtent = 56.0;
  static const _maxInitialPositionAttempts = 3;

  final Set<int> _collapsedGroups = {};
  final GlobalKey _currentChapterKey = GlobalKey();
  bool _hasPositionedCurrentChapter = false;
  int _initialPositionAttempts = 0;

  void _positionCurrentChapter(List<TocEntry> visibleEntries) {
    if (_hasPositionedCurrentChapter) {
      return;
    }

    final currentEntryIndex = visibleEntries.indexWhere(
      (entry) => entry.index == widget.currentChapterIndex,
    );
    if (currentEntryIndex < 0) {
      return;
    }

    _hasPositionedCurrentChapter = true;
    _scrollToCurrentChapter(currentEntryIndex);
  }

  void _toggleGroup(int groupId) {
    setState(() {
      if (_collapsedGroups.contains(groupId)) {
        _collapsedGroups.remove(groupId);
      } else {
        _collapsedGroups.add(groupId);
      }
    });
  }

  void _scrollToCurrentChapter(int currentEntryIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) {
        if (mounted && _initialPositionAttempts < _maxInitialPositionAttempts) {
          _initialPositionAttempts++;
          _scrollToCurrentChapter(currentEntryIndex);
        }
        return;
      }

      final position = widget.scrollController.position;
      if (position.maxScrollExtent == 0 &&
          currentEntryIndex > 0 &&
          _initialPositionAttempts < _maxInitialPositionAttempts) {
        _initialPositionAttempts++;
        _scrollToCurrentChapter(currentEntryIndex);
        return;
      }
      final targetOffset =
          (currentEntryIndex * _estimatedEntryExtent) -
          (position.viewportDimension - _estimatedEntryExtent) / 2;
      widget.scrollController.jumpTo(
        targetOffset.clamp(0.0, position.maxScrollExtent),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentChapterContext = _currentChapterKey.currentContext;
        if (currentChapterContext == null) return;
        unawaited(Scrollable.ensureVisible(currentChapterContext, alignment: 0.5));
      });
    });
  }

  // ponytail: shared with reader_side_panel via toc_hierarchy.dart
  List<TocEntry> _buildHierarchy() {
    final epubToc = widget.metadata.metadata?['epubToc'];
    if (epubToc is List && epubToc.isNotEmpty) {
      return buildTocFromEpubToc(epubToc.cast<Map<String, dynamic>>());
    }
    final defaultHierarchy = buildTocHierarchy(widget.metadata.chapterTitles);
    final allFlat = defaultHierarchy.every((e) => e.depth == 0 && !e.isGroup);
    if (allFlat && widget.loadedChapters.isNotEmpty) {
      return buildTocFromHeadings(widget.metadata.chapterTitles, widget.loadedChapters);
    }
    return defaultHierarchy;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildHierarchy();
    final visibleEntries = entries
        .where((e) => e.isGroup || !_collapsedGroups.contains(e.groupId))
        .toList();
    _positionCurrentChapter(visibleEntries);

    // MD-8.1: compute max chapter size for visual bars
    final maxSize = widget.loadedChapters.values.fold<int>(
      0,
      (max, ch) => max > ch.blocks.length ? max : ch.blocks.length,
    );
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
            itemCount: visibleEntries.length,
            itemBuilder: (context, index) {
              final entry = visibleEntries[index];
              final title = entry.title.isNotEmpty ? entry.title : 'Глава ${entry.index + 1}';
              final isActive = entry.index == widget.currentChapterIndex;
              final isGroup = entry.isGroup;
              final isCollapsed = _collapsedGroups.contains(entry.groupId);
              final isLoaded = widget.loadedChapters.containsKey(entry.index);
              final isUnloaded = !isLoaded && widget.isDynamicallyLoading;
              final groupToggleLabel = isCollapsed
                  ? 'Развернуть раздел $title'
                  : 'Свернуть раздел $title';

              // MD-8.1: chapter size bar
              final ch = widget.loadedChapters[entry.index];
              final blockCount = ch?.blocks.length ?? 0;
              final barFraction = maxSize > 0 ? blockCount / maxSize : 0.0;

              return ListTile(
                key: isActive ? _currentChapterKey : ValueKey('toc-entry-${entry.index}'),
                contentPadding: EdgeInsets.only(
                  left: 16.0 + entry.depth * 16.0,
                ),
                leading: isGroup
                    ? Semantics(
                        key: ValueKey('toc-group-toggle-${entry.index}'),
                        button: true,
                        label: groupToggleLabel,
                        expanded: !isCollapsed,
                        onTap: () => _toggleGroup(entry.groupId),
                        child: ExcludeSemantics(
                          child: IconButton(
                            tooltip: groupToggleLabel,
                            visualDensity: VisualDensity.compact,
                            iconSize: 20,
                            onPressed: () => _toggleGroup(entry.groupId),
                            icon: Icon(
                              isCollapsed ? Icons.chevron_right : Icons.expand_more,
                              color: Theme.of(context).colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
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
                subtitle: isGroup
                    ? null
                    : isActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: LinearProgressIndicator(
                          value: widget.currentChapterProgress.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      )
                    : entry.index < widget.currentChapterIndex
                    ? Text(
                        'прочитано',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                trailing: isGroup || blockCount == 0
                    ? null
                    : SizedBox(
                        width: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              height: 4,
                              width: 40 * barFraction.clamp(0.05, 1.0),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$blockCount',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                dense: true,
                onTap: () {
                  Navigator.of(context).pop();
                  final resolved = resolveTocAnchor(
                    metadata: widget.metadata.metadata,
                    anchor: entry.anchor,
                    chapterIndex: entry.index,
                  );
                  final targetChapter = resolved?.chapterIndex ?? entry.index;
                  final targetParagraph = resolved?.paragraphIndex ?? 0;
                  final progress = widget.metadata.chapterCount <= 1
                      ? 0.0
                      : targetChapter / (widget.metadata.chapterCount - 1);
                  widget.onJumpToPosition(
                    ReaderPosition(
                      bookId: widget.metadata.id,
                      chapterIndex: targetChapter,
                      paragraphIndex: targetParagraph,
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

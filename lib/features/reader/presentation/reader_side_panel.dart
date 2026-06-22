import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../bookmarks/data/bookmark_repository.dart';
import '../../notes/data/note_repository.dart';
import '../../quotes/data/quote_repository.dart';
import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';

class ReaderSidePanel extends ConsumerStatefulWidget {
  const ReaderSidePanel({
    super.key,
    required this.metadata,
    required this.currentChapterIndex,
    required this.scrollController,
    required this.width,
    this.onJumpToPosition,
  });

  final NormalizedBookMetadata metadata;
  final int currentChapterIndex;
  final ScrollController scrollController;
  final double width;
  final ValueChanged<ReaderPosition>? onJumpToPosition;

  @override
  ConsumerState<ReaderSidePanel> createState() => _ReaderSidePanelState();
}

class _ReaderSidePanelState extends ConsumerState<ReaderSidePanel> {
  late final BookmarkRepository _bookmarks;
  late final NoteRepository _notes;
  late final QuoteRepository _quotes;
  final Set<int> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    final database = ref.read(databaseProvider);
    _bookmarks = BookmarkRepository(database);
    _notes = NoteRepository(database);
    _quotes = QuoteRepository(database);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Содержание'),
                Tab(text: 'Закладки'),
                Tab(text: 'Заметки'),
                Tab(text: 'Цитаты'),
              ],
              isScrollable: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTableOfContents(context),
                  _buildBookmarks(),
                  _buildNotes(),
                  _buildQuotes(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableOfContents(BuildContext context) {
    final chapters = _buildHierarchy();
    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final item = chapters[index];
        final title = item.title.isNotEmpty ? item.title : 'Глава ${item.index + 1}';
        final isActive = item.index == widget.currentChapterIndex;
        final isGroup = item.isGroup;
        final isCollapsed = _collapsedGroups.contains(item.groupId);

        return ListTile(
          contentPadding: EdgeInsets.only(left: 12.0 + item.depth * 16.0),
          leading: isGroup
              ? GestureDetector(
                  onTap: () => setState(() {
                    if (isCollapsed) {
                      _collapsedGroups.remove(item.groupId);
                    } else {
                      _collapsedGroups.add(item.groupId);
                    }
                  }),
                  child: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                )
              : null,
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isActive
                  ? FontWeight.bold
                  : isGroup
                  ? FontWeight.w600
                  : FontWeight.normal,
              fontSize: isGroup ? 14 : 13,
              color: isActive ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: isActive
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: widget.metadata.chapterCount <= 1
                        ? 0.0
                        : (widget.currentChapterIndex / (widget.metadata.chapterCount - 1)).clamp(
                            0.0,
                            1.0,
                          ),
                    minHeight: 2,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                )
              : null,
          dense: true,
          onTap: () => _jumpToChapter(item.index),
        );
      },
    );
  }

  List<_TocItem> _buildHierarchy() {
    final titles = widget.metadata.chapterTitles;
    final items = <_TocItem>[];
    final depthStack = <_DepthInfo>[];

    for (var i = 0; i < titles.length; i++) {
      final title = i < titles.length ? titles[i] : '';
      final depth = _detectDepth(title);

      while (depthStack.isNotEmpty && depthStack.last.depth >= depth) {
        depthStack.removeLast();
      }

      final groupId = depthStack.isNotEmpty ? depthStack.last.groupId : i;

      items.add(
        _TocItem(
          index: i,
          title: title,
          depth: depth,
          isGroup: false,
          groupId: groupId,
        ),
      );

      depthStack.add(_DepthInfo(depth: depth, groupId: i, title: title));
    }

    // Mark parents: any index that appears in depthStack as a groupId for later items
    final parentIndices = <int>{};
    for (final item in items) {
      if (items.any((other) => other.groupId == item.index && other.index != item.index)) {
        parentIndices.add(item.index);
      }
    }

    return items.map((item) {
      if (parentIndices.contains(item.index)) {
        final titleIdx = depthStack.indexWhere((d) => d.groupId == item.index);
        final title = titleIdx >= 0 ? depthStack[titleIdx].title : item.title;
        return item.copyWith(isGroup: true, title: title);
      }
      return item;
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

  Widget _buildBookmarks() {
    return StreamBuilder<List<Bookmark>>(
      stream: _bookmarks.watchBookmarks(widget.metadata.id),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? const <Bookmark>[];
        if (bookmarks.isEmpty) return const Center(child: Text('Нет закладок'));
        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return _buildPositionTile(
              title: 'Закладка',
              subtitle: bookmark.selectedText ?? _positionText(bookmark.chapterIndex),
              position: _toReaderPosition(
                bookmark.chapterIndex,
                bookmark.paragraphIndex,
                bookmark.localOffset,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _bookmarks.deleteBookmark(bookmark.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotes() {
    return StreamBuilder<List<Note>>(
      stream: _notes.watchNotes(widget.metadata.id),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const <Note>[];
        if (notes.isEmpty) return const Center(child: Text('Нет заметок'));
        return ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return _buildPositionTile(
              title: 'Заметка',
              subtitle: note.content,
              position: _toReaderPosition(note.chapterIndex, note.paragraphIndex, note.localOffset),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _notes.deleteNote(note.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuotes() {
    return StreamBuilder<List<Quote>>(
      stream: _quotes.watchQuotes(widget.metadata.id),
      builder: (context, snapshot) {
        final quotes = snapshot.data ?? const <Quote>[];
        if (quotes.isEmpty) return const Center(child: Text('Нет цитат'));
        return ListView.builder(
          itemCount: quotes.length,
          itemBuilder: (context, index) {
            final quote = quotes[index];
            final subtitle = [
              quote.beforeContext,
              quote.selectedText,
              quote.afterContext,
            ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
            return _buildPositionTile(
              title: 'Цитата',
              subtitle: subtitle,
              position: _toReaderPosition(quote.chapterIndex, quote.paragraphIndex, 0.0),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _quotes.deleteQuote(quote.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPositionTile({
    required String title,
    required String subtitle,
    required ReaderPosition position,
    Widget? trailing,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      dense: true,
      trailing: trailing,
      onTap: () => widget.onJumpToPosition?.call(position),
    );
  }

  void _jumpToChapter(int chapterIndex) {
    final progress = widget.metadata.chapterCount <= 1
        ? 0.0
        : chapterIndex / (widget.metadata.chapterCount - 1);
    widget.onJumpToPosition?.call(
      ReaderPosition(
        bookId: widget.metadata.id,
        chapterIndex: chapterIndex,
        paragraphIndex: 0,
        progressPercent: progress,
        updatedAt: DateTime.now(),
      ),
    );
  }

  ReaderPosition _toReaderPosition(int chapterIndex, int paragraphIndex, double localOffset) {
    final progress = widget.metadata.chapterCount <= 1
        ? 0.0
        : chapterIndex / (widget.metadata.chapterCount - 1);
    return ReaderPosition(
      bookId: widget.metadata.id,
      chapterIndex: chapterIndex,
      paragraphIndex: paragraphIndex,
      localOffset: localOffset * 100.0,
      progressPercent: progress,
      updatedAt: DateTime.now(),
    );
  }

  String _positionText(int chapterIndex) {
    return 'Глава ${chapterIndex + 1}';
  }
}

class _TocItem {
  final int index;
  final String title;
  final int depth;
  final bool isGroup;
  final int groupId;

  const _TocItem({
    required this.index,
    required this.title,
    required this.depth,
    required this.isGroup,
    required this.groupId,
  });

  _TocItem copyWith({
    int? index,
    String? title,
    int? depth,
    bool? isGroup,
    int? groupId,
  }) {
    return _TocItem(
      index: index ?? this.index,
      title: title ?? this.title,
      depth: depth ?? this.depth,
      isGroup: isGroup ?? this.isGroup,
      groupId: groupId ?? this.groupId,
    );
  }
}

class _DepthInfo {
  final int depth;
  final int groupId;
  final String title;

  const _DepthInfo({required this.depth, required this.groupId, required this.title});
}

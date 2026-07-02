import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../bookmarks/data/bookmark_repository.dart';
import '../../notes/data/note_repository.dart';
import '../../quotes/data/quote_repository.dart';
import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';
import 'toc_hierarchy.dart';

class ReaderSidePanel extends ConsumerStatefulWidget {
  const ReaderSidePanel({
    super.key,
    required this.metadata,
    required this.currentChapterIndex,
    required this.scrollController,
    required this.width,
    this.onJumpToPosition,
    this.bookTitle,
  });

  final NormalizedBookMetadata metadata;
  final int currentChapterIndex;
  final ScrollController scrollController;
  final double width;
  final ValueChanged<ReaderPosition>? onJumpToPosition;
  final String? bookTitle;

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
    final visibleChapters = chapters
        .where((item) => item.isGroup || !_collapsedGroups.contains(item.groupId))
        .toList();
    return ListView.builder(
      itemCount: visibleChapters.length,
      itemBuilder: (context, index) {
        final item = visibleChapters[index];
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

  // ponytail: shared with table_of_contents_sheet via toc_hierarchy.dart
  List<TocEntry> _buildHierarchy() => buildTocHierarchy(widget.metadata.chapterTitles);

  Widget _buildBookmarks() {
    return StreamBuilder<List<Bookmark>>(
      stream: _bookmarks.watchBookmarks(widget.metadata.id),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? const <Bookmark>[];
        if (bookmarks.isEmpty) return const Center(child: Text('Нет закладок'));
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Копировать все закладки',
                onPressed: () => _exportBookmarks(bookmarks),
              ),
            ),
            Expanded(
              child: ListView.builder(
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
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportBookmarks(List<Bookmark> bookmarks) async {
    final buf = StringBuffer();
    for (final b in bookmarks) {
      final text = b.selectedText ?? _positionText(b.chapterIndex);
      buf.writeln('• $text');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Закладки скопированы'), duration: Duration(seconds: 1)),
      );
    }
  }

  Widget _buildNotes() {
    return StreamBuilder<List<Note>>(
      stream: _notes.watchNotes(widget.metadata.id),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const <Note>[];
        if (notes.isEmpty) return const Center(child: Text('Нет заметок'));
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Копировать все заметки',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final buf = StringBuffer();
                  for (final n in notes) {
                    buf.writeln('Глава ${n.chapterIndex + 1}: ${n.content}');
                    buf.writeln();
                  }
                  await Clipboard.setData(ClipboardData(text: buf.toString()));
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Заметки скопированы'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _buildPositionTile(
                    title: 'Заметка',
                    subtitle: note.content,
                    position: _toReaderPosition(
                      note.chapterIndex,
                      note.paragraphIndex,
                      note.localOffset,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _notes.deleteNote(note.id),
                    ),
                  );
                },
              ),
            ),
          ],
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Копировать с атрибуцией',
                    onPressed: () => _copyQuoteWithAttribution(quote),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _quotes.deleteQuote(quote.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _copyQuoteWithAttribution(Quote quote) async {
    final title = widget.bookTitle ?? 'Книга';
    final chapter = 'Глава ${quote.chapterIndex + 1}';
    final text = '"${quote.selectedText}" — $title, $chapter';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цитата скопирована'), duration: Duration(seconds: 1)),
      );
    }
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

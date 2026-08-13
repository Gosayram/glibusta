import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../reader/domain/reader.dart';
import '../data/annotation_export.dart';
import '../data/annotations_providers.dart';

const _pageSize = 50;

class AnnotationsScreen extends ConsumerStatefulWidget {
  final String? bookId;

  const AnnotationsScreen({super.key, this.bookId});

  @override
  ConsumerState<AnnotationsScreen> createState() => _AnnotationsScreenState();
}

class _AnnotationsScreenState extends ConsumerState<AnnotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _selectedColor;

  final List<Bookmark> _bookmarks = [];
  final List<Note> _notes = [];
  final List<Quote> _quotes = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialLoading = true;
  Object? _initialError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    unawaited(_loadPage(offset: 0));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({required int offset}) async {
    final notifier = ref.read(
      annotationPageProvider(
        AnnotationPageParams(bookId: widget.bookId, limit: _pageSize, offset: offset),
      ).future,
    );
    try {
      final page = await notifier;
      if (!mounted) return;
      setState(() {
        _bookmarks.addAll(page.bookmarks);
        _notes.addAll(page.notes);
        _quotes.addAll(page.quotes);
        final totalReturned = page.bookmarks.length + page.notes.length + page.quotes.length;
        if (totalReturned < _pageSize) {
          _hasMore = false;
        }
        _initialLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _initialError = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final offset = _bookmarks.length + _notes.length + _quotes.length;
    await _loadPage(offset: offset);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) _searchController.clear();
    });
  }

  Future<void> _exportAnnotations([
    AnnotationExportFormat format = AnnotationExportFormat.markdown,
  ]) async {
    final data = AnnotationData(
      bookmarks: _bookmarks,
      notes: _notes,
      quotes: _quotes,
    );
    try {
      final book = widget.bookId == null
          ? null
          : await ref.read(databaseProvider).bookDao.getBookById(widget.bookId!);
      final export = AnnotationExportFormatter.build(
        annotations: data,
        format: format,
        bookTitle: book?.title ?? 'Мои аннотации',
      );
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, 'glibusta', 'exports', export.filename));
      await file.parent.create(recursive: true);
      await file.writeAsString(export.content);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Экспорт аннотаций: ${book?.title ?? 'Мои аннотации'}',
        ),
      );
    } on Object {
      if (mounted) unawaited(SmartDialog.showToast('Не удалось экспортировать аннотации'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        appBar: AdaptiveAppBar(title: Text('Аннотации')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_initialError != null) {
      return Scaffold(
        appBar: const AdaptiveAppBar(title: Text('Аннотации')),
        body: ErrorStateWidget(
          message: 'Не удалось загрузить аннотации',
          details: _initialError.toString(),
          onRetry: () {
            setState(() {
              _initialLoading = true;
              _initialError = null;
              _bookmarks.clear();
              _notes.clear();
              _quotes.clear();
              _hasMore = true;
            });
            unawaited(_loadPage(offset: 0));
          },
        ),
      );
    }

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск аннотаций',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Аннотации'),
        actions: [
          PopupMenuButton<AnnotationExportFormat>(
            tooltip: 'Экспортировать аннотации',
            icon: const Icon(Icons.ios_share),
            onSelected: (format) => unawaited(_exportAnnotations(format)),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AnnotationExportFormat.markdown,
                child: Text('Экспортировать в Markdown'),
              ),
              PopupMenuItem(
                value: AnnotationExportFormat.plainText,
                child: Text('Экспортировать в TXT'),
              ),
              PopupMenuItem(
                value: AnnotationExportFormat.html,
                child: Text('Экспортировать в HTML'),
              ),
              PopupMenuItem(
                value: AnnotationExportFormat.json,
                child: Text('Экспортировать в JSON'),
              ),
            ],
          ),
          IconButton(
            tooltip: _isSearching ? 'Закрыть поиск' : 'Поиск аннотаций',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bookmark_border), text: 'Закладки'),
            Tab(icon: Icon(Icons.note_alt_outlined), text: 'Заметки'),
            Tab(icon: Icon(Icons.format_quote), text: 'Цитаты'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final usedColors = _notes
        .map((n) => n.highlightColor)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return Column(
      children: [
        if (usedColors.length > 1)
          _ColorFilterRow(
            colors: usedColors,
            selectedColor: _selectedColor,
            onColorTap: (color) {
              setState(() {
                _selectedColor = _selectedColor == color ? null : color;
              });
            },
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _BookmarkList(
                bookmarks: _bookmarks,
                bookId: widget.bookId,
                query: _searchController.text,
                hasMore: _hasMore,
                isLoadingMore: _isLoadingMore,
                onLoadMore: _loadMore,
              ),
              _NoteList(
                notes: _notes,
                bookId: widget.bookId,
                query: _searchController.text,
                colorFilter: _selectedColor,
                hasMore: _hasMore,
                isLoadingMore: _isLoadingMore,
                onLoadMore: _loadMore,
              ),
              _QuoteList(
                quotes: _quotes,
                bookId: widget.bookId,
                query: _searchController.text,
                hasMore: _hasMore,
                isLoadingMore: _isLoadingMore,
                onLoadMore: _loadMore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookmarkList extends ConsumerWidget {
  final List<Bookmark> bookmarks;
  final String? bookId;
  final String query;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _BookmarkList({
    required this.bookmarks,
    this.bookId,
    this.query = '',
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredBookmarks = bookmarks
        .where((bookmark) => _matchesQuery(query, bookmark.selectedText, bookmark.note))
        .toList(growable: false);
    if (filteredBookmarks.isEmpty) {
      if (bookmarks.isNotEmpty && query.trim().isNotEmpty) return const _SearchEmptyState();
      return const _EmptyState(
        icon: Icons.bookmark_border,
        message: 'Нет закладок',
        hint: 'Создавайте закладки при чтении',
      );
    }

    final itemCount = filteredBookmarks.length + (hasMore ? 1 : 0);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= filteredBookmarks.length) {
          if (!isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final bookmark = filteredBookmarks[index];
        return Dismissible(
          key: Key(bookmark.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
          ),
          confirmDismiss: (_) async {
            if (!context.mounted) return false;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Удалить закладку?'),
                content: const Text('Это действие нельзя отменить.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return false;
            final repo = ref.read(bookmarkRepoProvider);
            await repo.deleteBookmark(bookmark.id);
            unawaited(SmartDialog.showToast('Закладка удалена'));
            return true;
          },
          child: ListTile(
            leading: const Icon(Icons.bookmark),
            title: bookmark.selectedText != null
                ? Text(
                    bookmark.selectedText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text('Стр. ${bookmark.chapterIndex + 1}'),
            subtitle: Text(
              'Абзац ${bookmark.paragraphIndex + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _openReaderAtPosition(
              context,
              bookId: bookmark.bookId,
              chapterIndex: bookmark.chapterIndex,
              paragraphIndex: bookmark.paragraphIndex,
              localOffset: bookmark.localOffset,
              updatedAt: bookmark.createdAt,
            ),
          ),
        );
      },
    );
  }
}

class _NoteList extends ConsumerWidget {
  final List<Note> notes;
  final String? bookId;
  final String query;
  final String? colorFilter;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _NoteList({
    required this.notes,
    this.bookId,
    this.query = '',
    this.colorFilter,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredNotes = notes
        .where(
          (note) =>
              _matchesQuery(query, note.content) &&
              (colorFilter == null || note.highlightColor == colorFilter),
        )
        .toList(growable: false);
    if (filteredNotes.isEmpty) {
      if (notes.isNotEmpty && (query.trim().isNotEmpty || colorFilter != null)) {
        return const _SearchEmptyState();
      }
      return const _EmptyState(
        icon: Icons.note_alt_outlined,
        message: 'Нет заметок',
        hint: 'Создавайте заметки при чтении',
      );
    }

    final itemCount = filteredNotes.length + (hasMore ? 1 : 0);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= filteredNotes.length) {
          if (!isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final note = filteredNotes[index];
        return Dismissible(
          key: Key(note.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
          ),
          confirmDismiss: (_) async {
            if (!context.mounted) return false;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Удалить заметку?'),
                content: const Text('Это действие нельзя отменить.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return false;
            final repo = ref.read(noteRepoProvider);
            await repo.deleteNote(note.id);
            unawaited(SmartDialog.showToast('Заметка удалена'));
            return true;
          },
          child: ListTile(
            leading: Icon(
              Icons.note,
              color: _parseColor(note.highlightColor),
            ),
            title: Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Стр. ${note.chapterIndex + 1}, абзац ${note.paragraphIndex + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _openReaderAtPosition(
              context,
              bookId: note.bookId,
              chapterIndex: note.chapterIndex,
              paragraphIndex: note.paragraphIndex,
              localOffset: note.localOffset,
              updatedAt: note.updatedAt ?? note.createdAt,
            ),
          ),
        );
      },
    );
  }
}

class _QuoteList extends ConsumerWidget {
  final List<Quote> quotes;
  final String? bookId;
  final String query;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _QuoteList({
    required this.quotes,
    this.bookId,
    this.query = '',
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredQuotes = quotes
        .where(
          (quote) => _matchesQuery(
            query,
            quote.selectedText,
            quote.note,
            quote.beforeContext,
            quote.afterContext,
          ),
        )
        .toList(growable: false);
    if (filteredQuotes.isEmpty) {
      if (quotes.isNotEmpty && query.trim().isNotEmpty) return const _SearchEmptyState();
      return const _EmptyState(
        icon: Icons.format_quote,
        message: 'Нет цитат',
        hint: 'Выделяйте текст при чтении',
      );
    }

    final itemCount = filteredQuotes.length + (hasMore ? 1 : 0);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= filteredQuotes.length) {
          if (!isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final quote = filteredQuotes[index];
        return Dismissible(
          key: Key(quote.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
          ),
          confirmDismiss: (_) async {
            if (!context.mounted) return false;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Удалить цитату?'),
                content: const Text('Это действие нельзя отменить.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return false;
            final repo = ref.read(quoteRepoProvider);
            await repo.deleteQuote(quote.id);
            unawaited(SmartDialog.showToast('Цитата удалена'));
            return true;
          },
          child: ListTile(
            leading: const Icon(Icons.format_quote),
            title: Text(
              quote.selectedText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Стр. ${quote.chapterIndex + 1}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (quote.note != null && quote.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    quote.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => _openReaderAtPosition(
              context,
              bookId: quote.bookId,
              chapterIndex: quote.chapterIndex,
              paragraphIndex: quote.paragraphIndex,
              updatedAt: quote.createdAt,
            ),
          ),
        );
      },
    );
  }
}

void _openReaderAtPosition(
  BuildContext context, {
  required String bookId,
  required int chapterIndex,
  required int paragraphIndex,
  required DateTime updatedAt,
  double localOffset = 0,
}) {
  unawaited(
    context.push(
      '/reader/$bookId',
      extra: ReaderPosition(
        bookId: bookId,
        chapterIndex: chapterIndex,
        paragraphIndex: paragraphIndex,
        localOffset: localOffset * 100,
        updatedAt: updatedAt,
      ),
    ),
  );
}

bool _matchesQuery(String query, String? first, [String? second, String? third, String? fourth]) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;
  return [first, second, third, fourth].any(
    (value) => value?.toLowerCase().contains(normalizedQuery) ?? false,
  );
}

Color _parseColor(String? hexString) {
  if (hexString == null || hexString.isEmpty) return Colors.amber;
  final cleaned = hexString.startsWith('#') ? hexString.substring(1) : hexString;
  if (cleaned.length != 6 && cleaned.length != 8) return Colors.amber;
  final prefix = cleaned.length == 8 ? '0x' : '0xFF';
  final parsed = int.tryParse('$prefix$cleaned');
  if (parsed == null) return Colors.amber;
  return Color(parsed);
}

class _ColorFilterRow extends StatelessWidget {
  final List<String> colors;
  final String? selectedColor;
  final ValueChanged<String> onColorTap;

  const _ColorFilterRow({
    required this.colors,
    required this.selectedColor,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final hex in colors) ...[
            GestureDetector(
              onTap: () => onColorTap(hex),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _parseColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == hex
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.search_off,
      message: 'Ничего не найдено',
      hint: 'Измените запрос или очистите поиск',
    );
  }
}

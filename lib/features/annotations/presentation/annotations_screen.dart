import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../reader/domain/reader.dart';
import '../data/annotations_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final annotationsAsync = ref.watch(allAnnotationsProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
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
      body: annotationsAsync.when(
        data: (data) {
          return TabBarView(
            controller: _tabController,
            children: [
              _BookmarkList(
                bookmarks: data.bookmarks,
                bookId: widget.bookId,
                query: _searchController.text,
              ),
              _NoteList(notes: data.notes, bookId: widget.bookId, query: _searchController.text),
              _QuoteList(quotes: data.quotes, bookId: widget.bookId, query: _searchController.text),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: 'Не удалось загрузить аннотации',
          details: e.toString(),
          onRetry: () => ref.invalidate(allAnnotationsProvider(widget.bookId)),
        ),
      ),
    );
  }
}

class _BookmarkList extends ConsumerWidget {
  final List<Bookmark> bookmarks;
  final String? bookId;
  final String query;

  const _BookmarkList({required this.bookmarks, this.bookId, this.query = ''});

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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredBookmarks.length,
      itemBuilder: (context, index) {
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

  const _NoteList({required this.notes, this.bookId, this.query = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredNotes = notes
        .where((note) => _matchesQuery(query, note.content))
        .toList(growable: false);
    if (filteredNotes.isEmpty) {
      if (notes.isNotEmpty && query.trim().isNotEmpty) return const _SearchEmptyState();
      return const _EmptyState(
        icon: Icons.note_alt_outlined,
        message: 'Нет заметок',
        hint: 'Создавайте заметки при чтении',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
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

  const _QuoteList({required this.quotes, this.bookId, this.query = ''});

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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredQuotes.length,
      itemBuilder: (context, index) {
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
        // Annotation storage uses a 0..1 fraction; reader positions use 0..100.
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
  final parsed = int.tryParse('0xFF$cleaned');
  if (parsed == null) return Colors.amber;
  return Color(parsed);
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

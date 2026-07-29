import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/app_animations.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../reader/domain/reader.dart';
import '../data/bookmark_repository.dart';
import '../data/bookmarks_providers.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookmarksScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
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
    final bookmarksAsync = ref.watch(bookmarksStreamProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск закладок',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Закладки'),
        actions: [
          IconButton(
            tooltip: _isSearching ? 'Закрыть поиск' : 'Поиск закладок',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: bookmarksAsync.when(
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет закладок',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Закладки появятся при чтении книг',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => context.go('/library'),
                    child: const Text('Открыть библиотеку'),
                  ),
                ],
              ),
            );
          }

          final filteredBookmarks = bookmarks
              .where((bookmark) => _matchesBookmarkQuery(bookmark, _searchController.text))
              .toList(growable: false);
          if (filteredBookmarks.isEmpty) {
            return const _BookmarksSearchEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredBookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = filteredBookmarks[index];
              return BookmarkTile(
                bookmark: bookmark,
                onTap: () => context.push(
                  '/reader/${bookmark.bookId}',
                  extra: ReaderPosition(
                    bookId: bookmark.bookId,
                    chapterIndex: bookmark.chapterIndex,
                    paragraphIndex: bookmark.paragraphIndex,
                    localOffset: bookmark.localOffset * 100,
                    updatedAt: bookmark.createdAt,
                  ),
                ),
                onDelete: () => _deleteBookmark(context, ref, bookmark),
              ).animate().listTileTransition(delay: (index * 50).ms);
            },
          );
        },
        loading: () => Skeletonizer(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, _) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Bone.circle(size: 24),
                title: Text(BoneMock.name),
                subtitle: Text(BoneMock.subtitle),
              ),
            ),
          ),
        ),
        error: (e, _) => ErrorStateWidget(
          message: 'Не удалось загрузить закладки',
          details: e.toString(),
          onRetry: () => ref.invalidate(bookmarksStreamProvider(widget.bookId)),
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(BuildContext context, WidgetRef ref, Bookmark bookmark) async {
    final database = ref.read(databaseProvider);
    final repository = BookmarkRepository(database);
    await repository.deleteBookmark(bookmark.id);
    if (!context.mounted) return;
    unawaited(SmartDialog.showToast('Закладка удалена'));
  }
}

bool _matchesBookmarkQuery(Bookmark bookmark, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;
  return [bookmark.selectedText, bookmark.note].any(
    (value) => value?.toLowerCase().contains(normalizedQuery) ?? false,
  );
}

class _BookmarksSearchEmptyState extends StatelessWidget {
  const _BookmarksSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64),
          SizedBox(height: 16),
          Text('Ничего не найдено'),
          SizedBox(height: 8),
          Text('Измените запрос или очистите поиск'),
        ],
      ),
    );
  }
}

class BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const BookmarkTile({
    super.key,
    required this.bookmark,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final note = bookmark.note;
    return RepaintBoundary(
      child: Dismissible(
        key: Key(bookmark.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          return showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить закладку?'),
              content: const Text('Это действие можно отменить'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
        },
        background: Container(
          color: Theme.of(context).colorScheme.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
        ),
        onDismissed: (_) => onDelete?.call(),
        child: ListTile(
          leading: const Icon(Icons.bookmark),
          title: bookmark.selectedText != null
              ? Text(
                  bookmark.selectedText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : Text('Стр. ${bookmark.chapterIndex + 1}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Абзац ${bookmark.paragraphIndex + 1}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (note case final nonEmptyNote? when nonEmptyNote.isNotEmpty)
                Text(
                  nonEmptyNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

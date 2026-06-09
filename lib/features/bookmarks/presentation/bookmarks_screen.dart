import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../data/bookmark_repository.dart';

final bookmarksStreamProvider = StreamProvider.family<List<Bookmark>, String>((ref, bookId) {
  final database = ref.watch(databaseProvider);
  final repository = BookmarkRepository(database);
  return repository.watchBookmarks(bookId);
});

class BookmarksScreen extends ConsumerWidget {
  final String bookId;

  const BookmarksScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksStreamProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Закладки'),
      ),
      body: bookmarksAsync.when(
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Нет закладок', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text(
                    'Закладки появятся при чтении книг',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return BookmarkTile(
                bookmark: bookmark,
                onTap: () {},
                onDelete: () {
                  _deleteBookmark(ref, bookmark.id);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: 'Не удалось загрузить закладки',
          details: e.toString(),
          onRetry: () => ref.invalidate(bookmarksStreamProvider(bookId)),
        ),
      ),
    );
  }

  void _deleteBookmark(WidgetRef ref, String id) {
    final database = ref.read(databaseProvider);
    final repository = BookmarkRepository(database);
    unawaited(repository.deleteBookmark(id));
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
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
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
        subtitle: Text(
          'Абзац ${bookmark.paragraphIndex + 1}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
      ),
    );
  }
}

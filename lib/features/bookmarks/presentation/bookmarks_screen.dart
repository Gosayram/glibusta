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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
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
          onRetry: () => ref.invalidate(bookmarksStreamProvider(bookId)),
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
          subtitle: Text(
            'Абзац ${bookmark.paragraphIndex + 1}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

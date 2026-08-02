import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../reader/domain/reader.dart';
import '../data/bookmark_repository.dart';
import 'bookmarks_screen.dart';

class AllBookmarksScreen extends ConsumerStatefulWidget {
  const AllBookmarksScreen({super.key});

  @override
  ConsumerState<AllBookmarksScreen> createState() => _AllBookmarksScreenState();
}

class _AllBookmarksScreenState extends ConsumerState<AllBookmarksScreen> {
  @override
  Widget build(BuildContext context) {
    final repository = BookmarkRepository(ref.read(databaseProvider));
    return FutureBuilder<List<Bookmark>>(
      future: repository.getBookmarksPage(limit: 200, offset: 0),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: AdaptiveAppBar(title: Text('Закладки')),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: const AdaptiveAppBar(title: Text('Закладки')),
            body: ErrorStateWidget(
              message: 'Не удалось загрузить закладки',
              details: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            ),
          );
        }
        final bookmarks = snapshot.data ?? [];
        if (bookmarks.isEmpty) {
          return Scaffold(
            appBar: const AdaptiveAppBar(title: Text('Закладки')),
            body: Center(
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
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: const AdaptiveAppBar(title: Text('Закладки')),
          body: ListView.builder(
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
                onDelete: () async {
                  final database = ref.read(databaseProvider);
                  final repo = BookmarkRepository(database);
                  await repo.deleteBookmark(bookmark.id);
                  if (!context.mounted) return;
                  unawaited(SmartDialog.showToast('Закладка удалена'));
                  if (mounted) setState(() {});
                },
              );
            },
          ),
        );
      },
    );
  }
}

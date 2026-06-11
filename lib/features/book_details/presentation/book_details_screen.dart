import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart' as auth;
import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/widgets/book_cover_image.dart';
import '../data/book_comments_service.dart';
import '../data/book_details_repository_impl.dart';
import 'book_details_providers.dart';

final bookDetailsProvider = FutureProvider.family<BookDetails, String>((ref, bookId) async {
  final repository = ref.watch(bookDetailsRepositoryProvider);
  return repository.getBookDetails(bookId);
});

final bookReadingProgressProvider = FutureProvider.family<ReadingProgressData?, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.getReadingProgress(bookId);
});

class BookDetailsScreen extends ConsumerWidget {
  final String bookId;

  const BookDetailsScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(bookDetailsProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('О книге')),
      body: detailsAsync.when(
        data: (BookDetails details) => _BookDetailsContent(details: details, bookId: bookId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text('Ошибка загрузки: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(bookDetailsProvider(bookId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookDetailsContent extends ConsumerStatefulWidget {
  final BookDetails details;
  final String bookId;

  const _BookDetailsContent({required this.details, required this.bookId});

  @override
  ConsumerState<_BookDetailsContent> createState() => _BookDetailsContentState();
}

class _BookDetailsContentState extends ConsumerState<_BookDetailsContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.details.book;
    final theme = Theme.of(context);
    final progressAsync = ref.watch(bookReadingProgressProvider(widget.bookId));

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _BookHeader(book: book, details: widget.details),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildReadingProgress(progressAsync),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SeriesInfoSection(bookId: widget.bookId),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(tabController: _tabController, theme: theme),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DescriptionTab(description: widget.details.description ?? book.description),
                    _ChaptersTab(bookId: widget.bookId),
                    _BookmarksTab(bookId: widget.bookId),
                    _QuotesTab(bookId: widget.bookId),
                    _CommentsTab(bookId: widget.bookId),
                  ],
                ),
              ),
            ],
          ),
        ),
        _BottomActionBar(book: book, details: widget.details),
      ],
    );
  }

  Widget? _buildReadingProgress(AsyncValue<ReadingProgressData?> progressAsync) {
    if (progressAsync.isLoading || progressAsync.hasError) return null;
    final progress = progressAsync.value;
    if (progress == null) return null;
    return _ReadingProgressIndicator(progress: progress);
  }
}

class _BookHeader extends StatelessWidget {
  final Book book;
  final BookDetails details;

  const _BookHeader({required this.book, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 130,
              height: 190,
              child: BookCoverImage(book: book),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                book.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (book.authorIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  book.displayAuthor.isNotEmpty ? book.displayAuthor : book.authorIds.join(', '),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (book.publishDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  book.publishDate!.year.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (details.availableFormats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: details.availableFormats.map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        f.name.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ReadingProgressIndicator extends StatelessWidget {
  final ReadingProgressData progress;

  const _ReadingProgressIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress.totalPages > 0
        ? (progress.currentPosition / progress.totalPages).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогресс чтения',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: percent, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _SeriesInfoSection extends ConsumerWidget {
  final String bookId;

  const _SeriesInfoSection({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final seriesAsync = ref.watch(seriesForBookProvider(bookId));

    return seriesAsync.when(
      data: (seriesList) {
        if (seriesList.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in seriesList)
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/series/${s.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.collections_bookmark,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Серия',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final ThemeData theme;

  _TabBarDelegate({required this.tabController, required this.theme});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: tabController,
        tabs: const [
          Tab(text: 'Описание'),
          Tab(text: 'Главы'),
          Tab(text: 'Закладки'),
          Tab(text: 'Цитаты'),
          Tab(text: 'Комментарии'),
        ],
        labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: theme.textTheme.labelMedium,
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabController != oldDelegate.tabController || theme != oldDelegate.theme;
}

class _DescriptionTab extends StatelessWidget {
  final String? description;

  const _DescriptionTab({this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (description == null || description!.isEmpty) {
      return Center(
        child: Text('Нет описания', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(description!, style: theme.textTheme.bodyMedium),
    );
  }
}

class _ChaptersTab extends ConsumerWidget {
  final String bookId;

  const _ChaptersTab({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(chaptersForBookProvider(bookId));

    return chaptersAsync.when(
      data: (book) {
        if (book == null) {
          return Center(
            child: Text(
              'Откройте книгу, чтобы увидеть главы',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        final chapters = book.chapters;
        return ListView.builder(
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text('${index + 1}', style: theme.textTheme.labelSmall),
              ),
              title: Text(chapters[index].title, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => unawaited(context.push('/reader/$bookId')),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          'Откройте книгу, чтобы увидеть главы',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  final String bookId;

  const _BookmarksTab({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarksAsync = ref.watch(bookmarksForBookProvider(bookId));

    return bookmarksAsync.when(
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Text(
              'Нет закладок',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return ListTile(
              leading: const Icon(Icons.bookmark, size: 20),
              title: Text(
                bookmark.selectedText ?? 'Глава ${bookmark.chapterIndex + 1}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: bookmark.note != null ? Text(bookmark.note!) : null,
              onTap: () => unawaited(context.push('/reader/$bookId')),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          'Нет закладок',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _QuotesTab extends ConsumerWidget {
  final String bookId;

  const _QuotesTab({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final quotesAsync = ref.watch(quotesForBookProvider(bookId));

    return quotesAsync.when(
      data: (quotes) {
        if (quotes.isEmpty) {
          return Center(
            child: Text('Нет цитат', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          itemCount: quotes.length,
          itemBuilder: (context, index) {
            final quote = quotes[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_quote, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Глава ${quote.chapterIndex + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quote.selectedText,
                        style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (quote.note != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(quote.note!, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text('Нет цитат', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _CommentsTab extends ConsumerStatefulWidget {
  final String bookId;

  const _CommentsTab({required this.bookId});

  @override
  ConsumerState<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<_CommentsTab> {
  final _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsForBookProvider(widget.bookId));
    final authData = ref.watch(auth.authStateProvider).value;
    final isAuthenticated = authData?.isAuthenticated ?? false;

    return commentsAsync.when(
      data: (comments) => _buildBody(theme, comments, isAuthenticated),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _buildBody(theme, const [], isAuthenticated),
    );
  }

  Widget _buildBody(ThemeData theme, List<BookComment> comments, bool isAuthenticated) {
    return Column(
      children: [
        Expanded(
          child: comments.isEmpty
              ? Center(
                  child: Text(
                    'Нет комментариев',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  comment.author,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                if (comment.createdAt != null) ...[
                                  const Spacer(),
                                  Text(
                                    _formatDate(comment.createdAt!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(comment.text, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: !isAuthenticated
                ? Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Войдите, чтобы оставить комментарий',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _LoginPlaceholder(),
                          ),
                        ),
                        child: const Text('Войти'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Комментарий...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _postComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isPosting ? null : _postComment,
                        icon: _isPosting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send, size: 18),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final authState = ref.read(auth.authStateProvider).value;
    if (authState?.session == null) return;

    setState(() => _isPosting = true);
    try {
      final service = ref.read(bookCommentsServiceProvider);
      final cookies = authState!.session!.cookies;
      final success = await service.postComment(
        bookId: widget.bookId,
        body: text,
        cookies: cookies,
      );
      if (success && mounted) {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Комментарий отправлен')),
        );
        ref.invalidate(commentsForBookProvider(widget.bookId));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить комментарий')),
        );
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка отправки')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

class _LoginPlaceholder extends StatelessWidget {
  const _LoginPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: const Center(
        child: Text('Откройте Настройки → Вход для авторизации'),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final Book book;
  final BookDetails details;

  const _BottomActionBar({required this.book, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => unawaited(context.push('/reader/${book.id}')),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Читать'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: details.availableFormats.isNotEmpty
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скоро будет доступно')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.download),
              label: const Text('Скачать'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/auth/auth_repository.dart' as auth;
import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../data/book_comments_service.dart';
import 'book_details_providers.dart';
import 'widgets/book_header.dart';
import 'widgets/bottom_action_bar.dart';
import 'widgets/reading_progress_indicator.dart';
import 'widgets/series_info_section.dart';

class BookDetailsScreen extends ConsumerWidget {
  final String bookId;

  const BookDetailsScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(bookDetailsProvider(bookId));

    return Scaffold(
      appBar: const AdaptiveAppBar(title: Text('О книге')),
      body: detailsAsync.when(
        data: (BookDetails details) => BookDetailsContent(details: details, bookId: bookId),
        loading: () => const Skeletonizer(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton.replace(
                      child: Bone(width: 120, height: 180),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone(width: 120, height: 12),
                          SizedBox(height: 8),
                          Bone(width: 80, height: 12),
                          SizedBox(height: 8),
                          Bone(width: 120, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Bone(height: 40),
                SizedBox(height: 16),
                Bone(height: 100),
              ],
            ),
          ),
        ),
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

class BookDetailsContent extends ConsumerStatefulWidget {
  final BookDetails details;
  final String bookId;

  const BookDetailsContent({super.key, required this.details, required this.bookId});

  @override
  ConsumerState<BookDetailsContent> createState() => BookDetailsContentState();
}

class BookDetailsContentState extends ConsumerState<BookDetailsContent>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _lastTabCount = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.details.book;
    final theme = Theme.of(context);
    final progressAsync = ref.watch(bookReadingProgressProvider(widget.bookId));

    final chaptersAsync = ref.watch(chaptersForBookProvider(widget.bookId));
    final bookmarksAsync = ref.watch(bookmarksForBookProvider(widget.bookId));
    final quotesAsync = ref.watch(quotesForBookProvider(widget.bookId));

    final hasChapters =
        chaptersAsync.hasValue &&
        chaptersAsync.value != null &&
        chaptersAsync.value!.chapters.isNotEmpty;
    final hasBookmarks =
        bookmarksAsync.hasValue && bookmarksAsync.value != null && bookmarksAsync.value!.isNotEmpty;
    final hasQuotes =
        quotesAsync.hasValue && quotesAsync.value != null && quotesAsync.value!.isNotEmpty;

    final tabs = <Widget>[];
    final tabViews = <Widget>[];

    tabs.add(const Tab(text: 'Описание'));
    tabViews.add(_DescriptionTab(description: widget.details.description ?? book.description));

    if (hasChapters) {
      tabs.add(const Tab(text: 'Главы'));
      tabViews.add(_ChaptersTab(bookId: widget.bookId));
    }

    if (hasBookmarks) {
      tabs.add(const Tab(text: 'Закладки'));
      tabViews.add(_BookmarksTab(bookId: widget.bookId));
    }

    if (hasQuotes) {
      tabs.add(const Tab(text: 'Цитаты'));
      tabViews.add(_QuotesTab(bookId: widget.bookId));
    }

    tabs.add(const Tab(text: 'Комментарии'));
    tabViews.add(_CommentsTab(bookId: widget.bookId));

    final tabCount = tabs.length;
    if (tabCount != _lastTabCount) {
      _tabController?.dispose();
      _lastTabCount = tabCount;
      _tabController = TabController(length: tabCount, vsync: this);
    }

    final controller = _tabController!;
    if (controller.index >= tabCount) {
      controller.index = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return _buildWideLayout(
            context,
            book,
            theme,
            controller,
            tabs,
            tabViews,
            progressAsync,
          );
        }
        return _buildNarrowLayout(
          context,
          book,
          theme,
          controller,
          tabs,
          tabViews,
          progressAsync,
        );
      },
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    Book book,
    ThemeData theme,
    TabController controller,
    List<Widget> tabs,
    List<Widget> tabViews,
    AsyncValue<ReadingProgressData?> progressAsync,
  ) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: BookHeader(book: book, details: widget.details),
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
                  child: SeriesInfoSection(bookId: widget.bookId),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabController: controller,
                  theme: theme,
                  tabs: tabs,
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: controller,
                  children: tabViews,
                ),
              ),
            ],
          ),
        ),
        BottomActionBar(book: book, details: widget.details),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    Book book,
    ThemeData theme,
    TabController controller,
    List<Widget> tabs,
    List<Widget> tabViews,
    AsyncValue<ReadingProgressData?> progressAsync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: BookHeader(book: book, details: widget.details),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: _buildReadingProgress(progressAsync),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: SeriesInfoSection(bookId: widget.bookId),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: BottomActionBar(book: book, details: widget.details),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Material(
                child: TabBar(
                  controller: controller,
                  tabs: tabs,
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: controller,
                  children: tabViews,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildReadingProgress(AsyncValue<ReadingProgressData?> progressAsync) {
    if (progressAsync.isLoading || progressAsync.hasError) return null;
    final progress = progressAsync.value;
    if (progress == null) return null;
    return ReadingProgressIndicator(progress: progress);
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final ThemeData theme;
  final List<Widget> tabs;

  _TabBarDelegate({required this.tabController, required this.theme, required this.tabs});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: tabController,
        tabs: tabs,
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
      tabController != oldDelegate.tabController ||
      theme != oldDelegate.theme ||
      tabs.length != oldDelegate.tabs.length;
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
              key: ValueKey(chapters[index].index),
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
              key: ValueKey(bookmark.id),
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
              key: ValueKey(quote.id),
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
                      key: ValueKey(comment.id),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: isAuthenticated
                          ? 'Комментарий...'
                          : 'Войдите, чтобы комментировать',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    enabled: isAuthenticated,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isAuthenticated)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _LoginPlaceholder(),
                      ),
                    ),
                    child: const Text('Войти'),
                  )
                else
                  IconButton.filled(
                    onPressed: _isPosting ? null : _postComment,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
        unawaited(SmartDialog.showToast('Комментарий отправлен'));
        ref.invalidate(commentsForBookProvider(widget.bookId));
      } else if (mounted) {
        unawaited(SmartDialog.showToast('Не удалось отправить комментарий'));
      }
    } on Object catch (_) {
      if (mounted) {
        unawaited(SmartDialog.showToast('Ошибка отправки'));
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
    return const Scaffold(
      appBar: AdaptiveAppBar(title: Text('Вход')),
      body: Center(
        child: Text('Откройте Настройки → Вход для авторизации'),
      ),
    );
  }
}

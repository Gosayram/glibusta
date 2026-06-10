import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/widgets/book_cover_image.dart';
import '../../library/data/book_repository_impl.dart';
import '../../reader/data/book_open_service.dart';
import '../../reader/data/parsers/normalized_book.dart';
import '../data/book_details_repository_impl.dart';

part 'book_details_screen.g.dart';

@riverpod
Future<BookDetails> bookDetails(Ref ref, String bookId) async {
  final repository = ref.watch(bookDetailsRepositoryProvider);
  return repository.getBookDetails(bookId);
}

@riverpod
Future<ReadingProgressData?> bookReadingProgress(Ref ref, String bookId) async {
  final db = ref.watch(databaseProvider);
  return db.getReadingProgress(bookId);
}

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
    _tabController = TabController(length: 4, vsync: this);
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
                sliver: SliverToBoxAdapter(child: _BookHeader(book: book, details: widget.details)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: progressAsync.when(
                    data: (ReadingProgressData? progress) {
                      if (progress == null) return const SizedBox.shrink();
                      return _ReadingProgressIndicator(progress: progress);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
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
        Container(
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
                  book.authorIds.join(', '),
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final ThemeData theme;

  _TabBarDelegate({required this.tabController, required this.theme});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: tabController,
        tabs: const [
          Tab(text: 'Описание'),
          Tab(text: 'Главы'),
          Tab(text: 'Закладки'),
          Tab(text: 'Цитаты'),
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
    final service = ref.read<BookOpenService>(bookOpenServiceProvider);

    return FutureBuilder<NormalizedBook?>(
      future: service.getCachedBook(bookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Text(
              'Откройте книгу, чтобы увидеть главы',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        final chapters = snapshot.data!.chapters;
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
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  final String bookId;

  const _BookmarksTab({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.read<AppDatabase>(databaseProvider);

    return FutureBuilder<List<Bookmark>>(
      future: db.getBookmarksForBook(bookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('Нет закладок', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final bookmark = snapshot.data![index];
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
    );
  }
}

class _QuotesTab extends ConsumerWidget {
  final String bookId;

  const _QuotesTab({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.read<AppDatabase>(databaseProvider);

    return FutureBuilder<List<Quote>>(
      future: db.getQuotesForBook(bookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('Нет цитат', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final quote = snapshot.data![index];
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
              onPressed: details.availableFormats.isNotEmpty ? () => _downloadBook(context) : null,
              icon: const Icon(Icons.download),
              label: const Text('Скачать'),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadBook(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Загрузка начата')));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/app_animations.dart';
import '../../../shared/widgets/book_card.dart';
import '../../collections/presentation/collections_screen.dart';
import '../../library/data/book_repository_impl.dart';
import '../../library/presentation/pinned_books_provider.dart';
import 'continue_reading_card.dart';
import 'continue_reading_provider.dart';
import 'reading_heatmap.dart';
import 'reading_stats_provider.dart';

final recentBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueReadingAsync = ref.watch(continueReadingInfosProvider);
    final booksAsync = ref.watch(recentBooksProvider);
    final pinnedAsync = ref.watch(pinnedBooksListProvider);
    final collectionsAsync = ref.watch(userCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glibusta'),
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Smart Continue Reading section
                const _SectionHeader(title: 'Продолжить чтение'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: continueReadingAsync.when(
                    data: (infos) {
                      if (infos.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Начните читать книгу',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: infos.length,
                        itemBuilder: (context, index) {
                          final info = infos[index];
                          return ContinueReadingCard(
                            info: info,
                            onTap: () => context.push('/reader/${info.book.id}'),
                          ).animate().bookCardTransition(delay: (index * 80).ms);
                        },
                      );
                    },
                    loading: () => SizedBox(
                      height: 160,
                      child: Skeletonizer(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 3,
                          itemBuilder: (_, _) => SizedBox(
                            width: 280,
                            child: Card(
                              margin: const EdgeInsets.only(right: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Skeleton.replace(child: Bone(width: 60, height: 90)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(BoneMock.name),
                                          const SizedBox(height: 8),
                                          Text(BoneMock.subtitle),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (_, _) => const Center(child: Text('Ошибка загрузки')),
                  ),
                ),
                const SizedBox(height: 24),
                // Reading stats section
                const _SectionHeader(title: 'Статистика чтения'),
                const SizedBox(height: 8),
                const _ReadingStatsSection(),
                const SizedBox(height: 24),
                // Pinned books section
                pinnedAsync.when(
                  data: (List<Book> pinnedBooks) {
                    if (pinnedBooks.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'Закреплённые'),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: pinnedBooks.length,
                            itemBuilder: (context, index) {
                              final book = pinnedBooks[index];
                              return SizedBox(
                                width: 120,
                                child: BookCard(
                                  key: ValueKey(book.id),
                                  book: book,
                                  onTap: () => context.push('/book/${book.id}'),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                // Collections section
                collectionsAsync.when(
                  data: (List<Collection> collections) {
                    if (collections.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _SectionHeader(title: 'Коллекции'),
                            TextButton(
                              onPressed: () => context.go('/collections'),
                              child: const Text('Все'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final col in collections.take(3)) _CollectionTile(collection: col),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const _SectionHeader(title: 'Недавно добавленные'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: booksAsync.when(
                    data: (List<Book> books) {
                      if (books.isEmpty) {
                        return Center(
                          child: Text(
                            'Библиотека пуста',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        );
                      }
                      final recent = books.length > 5 ? books.sublist(0, 5) : books;
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final book = recent[index];
                          return SizedBox(
                                width: 120,
                                child: BookCard(
                                  key: ValueKey(book.id),
                                  book: book,
                                  onTap: () => context.push('/book/${book.id}'),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: (index * 60).ms, duration: 400.ms)
                              .slideY(begin: 0.05, duration: 400.ms);
                        },
                      );
                    },
                    loading: () => SizedBox(
                      height: 180,
                      child: Skeletonizer(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 5,
                          itemBuilder: (_, _) => SizedBox(
                            width: 120,
                            child: Card(
                              child: Column(
                                children: [
                                  const Skeleton.replace(child: Bone(height: 120)),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(BoneMock.subtitle),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (_, _) => const Center(child: Text('Ошибка загрузки')),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Быстрые действия'),
                const SizedBox(height: 8),
                _QuickActionRow(
                  children: [
                    _QuickAction(
                      icon: Icons.download,
                      label: 'Загрузки',
                      onTap: () => context.go('/downloads'),
                    ),
                    _QuickAction(
                      icon: Icons.collections_bookmark,
                      label: 'Серии',
                      onTap: () => context.go('/series'),
                    ),
                    _QuickAction(
                      icon: Icons.bookmark,
                      label: 'Закладки',
                      onTap: () => context.go('/library'),
                    ),
                    _QuickAction(
                      icon: Icons.settings,
                      label: 'Настройки',
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ).animate().sectionFadeIn();
  }
}

class _QuickActionRow extends StatelessWidget {
  final List<Widget> children;

  const _QuickActionRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          icon: Icon(icon),
          onPressed: onTap,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ReadingStatsSection extends ConsumerWidget {
  const _ReadingStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(readingStatsProvider);
    final theme = Theme.of(context);

    return statsAsync.when(
      data: (stats) {
        if (stats.totalMinutes == 0 && stats.currentStreak == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Начните читать, чтобы увидеть статистику',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.local_fire_department,
                      label: stats.streakText,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.today,
                      label: stats.todayText,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StatChip(
                  icon: Icons.calendar_month,
                  label: stats.monthText,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: 16),
                // Heatmap
                ReadingHeatmap(data: stats.heatmapData),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Skeletonizer(
            child: Column(
              children: [
                Row(
                  children: [
                    Bone.circle(size: 32),
                    SizedBox(width: 8),
                    Bone.circle(size: 32),
                    SizedBox(width: 8),
                    Bone.circle(size: 32),
                  ],
                ),
                SizedBox(height: 16),
                Bone(height: 100),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final Collection collection;

  const _CollectionTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookCount = collection.bookIds.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.folder,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          collection.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$bookCount ${bookCount == 1
              ? 'книга'
              : bookCount < 5
              ? 'книги'
              : 'книг'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        onTap: () => context.go('/collections'),
      ),
    );
  }
}

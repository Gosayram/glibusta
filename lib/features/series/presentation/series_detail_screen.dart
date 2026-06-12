import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../shared/widgets/book_card.dart';
import 'series_provider.dart';

class SeriesDetailScreen extends ConsumerWidget {
  final String seriesId;

  const SeriesDetailScreen({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(seriesDetailProvider(seriesId));

    return Scaffold(
      appBar: detailAsync.when(
        data: (SeriesDetail? detail) => AppBar(
          title: Text(detail?.name ?? 'Серия'),
        ),
        loading: () => AppBar(title: const Text('Серия')),
        error: (_, _) => AppBar(title: const Text('Серия')),
      ),
      body: detailAsync.when(
        data: (SeriesDetail? detail) {
          if (detail == null) {
            return const Center(child: Text('Серия не найдена'));
          }
          if (detail.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.collections_bookmark_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет книг в серии',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.description != null && detail.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    detail.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '${detail.books.length} ${_bookCountText(detail.books.length)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: detail.books.length,
                  itemBuilder: (context, int index) {
                    final book = detail.books[index];
                    return BookCard(
                          key: ValueKey(book.id),
                          book: book,
                          onTap: () => context.push('/book/${book.id}'),
                        )
                        .animate()
                        .fadeIn(delay: (index * 60).ms, duration: 400.ms)
                        .scale(begin: const Offset(0.95, 0.95), duration: 400.ms);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Skeletonizer(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Bone.text(words: 3),
                const SizedBox(height: 8),
                const Bone.text(words: 5),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (_, _) => const SizedBox(
                      width: 120,
                      child: Card(
                        child: Column(
                          children: [
                            Bone(height: 120),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Bone.text(words: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (Object e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }

  String _bookCountText(int count) {
    if (count == 1) return 'книга';
    if (count >= 2 && count <= 4) return 'книги';
    return 'книг';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../data/recent_books_provider.dart';

class RecentBooksScreen extends ConsumerWidget {
  const RecentBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBooks = ref.watch(recentBooksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Недавно добавленные')),
      body: asyncBooks.when(
        data: (response) {
          if (response.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет недавно добавленных книг',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  '${response.books.length} ${_bookCountText(response.books.length)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: response.books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final book = response.books[index];
                    return ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            book.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => context.push('/book/${book.id}'),
                        )
                        .animate()
                        .fadeIn(
                          delay: (index * 40).ms,
                          duration: 300.ms,
                        )
                        .slideX(begin: 0.05, duration: 300.ms);
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
                const Bone.text(words: 2),
                const SizedBox(height: 16),
                for (var i = 0; i < 6; i++) ...[
                  const ListTile(
                    leading: Bone.circle(size: 40),
                    title: Bone.text(words: 4),
                  ),
                  const SizedBox(height: 4),
                ],
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
                onPressed: () => ref.invalidate(recentBooksProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bookCountText(int count) {
    if (count == 1) return 'книга';
    if (count >= 2 && count <= 4) return 'книги';
    return 'книг';
  }
}

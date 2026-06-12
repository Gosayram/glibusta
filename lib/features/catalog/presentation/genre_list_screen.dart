import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../data/genre_providers.dart';

class GenreListScreen extends ConsumerWidget {
  const GenreListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(genreListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Жанры')),
      body: asyncList.when(
        data: (response) {
          if (response.genres.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет жанров',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: response.genres.length,
            itemBuilder: (context, index) {
              final genre = response.genres[index];
              return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/genre/${genre.id}'),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            genre.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (index * 30).ms, duration: 300.ms)
                  .scale(begin: const Offset(0.95, 0.95), duration: 300.ms);
            },
          );
        },
        loading: () => Skeletonizer(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (_, _) => const Card(
              child: Center(child: Bone.text(words: 2)),
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
                onPressed: () => ref.invalidate(genreListProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

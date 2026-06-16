import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../shared/widgets/app_animations.dart';

import '../data/genre_providers.dart';

class GenreListScreen extends ConsumerStatefulWidget {
  const GenreListScreen({super.key});

  @override
  ConsumerState<GenreListScreen> createState() => _GenreListScreenState();
}

class _GenreListScreenState extends ConsumerState<GenreListScreen> {
  final _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(genreListProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth < 600
        ? 2
        : screenWidth < 900
        ? 3
        : 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Жанры'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: 'Фильтр...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _filterController.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: asyncList.when(
        data: (response) {
          final genres = _filter.isEmpty
              ? response.genres
              : response.genres.where((g) => g.name.toLowerCase().contains(_filter)).toList();

          if (genres.isEmpty) {
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
                    _filter.isNotEmpty ? 'Ничего не найдено' : 'Нет жанров',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/genre/${genre.id}'),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        genre.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ).animate().genreCardFadeIn(delay: (index * 10).ms);
            },
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
          ),
          itemCount: 12,
          itemBuilder: (_, _) => Card(
            child: Center(
              child: Text(BoneMock.name),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Ошибка загрузки жанров'),
              const SizedBox(height: 8),
              FilledButton.tonal(
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

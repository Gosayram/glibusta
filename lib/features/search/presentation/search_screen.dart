import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/platform/adaptive_context.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover_image.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final SearchController _searchController = SearchController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(searchControllerProvider.notifier).loadHistory());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _genreController.dispose();
    _languageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      ref.read(searchControllerProvider.notifier).clearResults();
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(ref.read(searchControllerProvider.notifier).search(value.trim()));
    });
  }

  void _setFormatFilter(BookFormat? format) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(format: format, clearFormat: format == null),
        );
  }

  void _setGenreFilter(String value) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(genre: value.trim(), clearGenre: value.trim().isEmpty),
        );
  }

  void _setLanguageFilter(String value) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(
            language: value.trim(),
            clearLanguage: value.trim().isEmpty,
          ),
        );
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    _genreController.clear();
    _languageController.clear();
    ref.read(searchControllerProvider.notifier).setFilters(const SearchFilters());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: SearchAnchor.bar(
          searchController: _searchController,
          viewHintText: 'Поиск книг...',
          onChanged: _onSearchChanged,
          onSubmitted: (value) {
            _debounceTimer?.cancel();
            if (value.trim().isNotEmpty) {
              _searchController.closeView(value.trim());
              unawaited(ref.read(searchControllerProvider.notifier).search(value.trim()));
            }
          },
          suggestionsBuilder: (context, controller) {
            if (state.history.isEmpty) {
              return [
                const ListTile(
                  enabled: false,
                  title: Text('Нет недавних запросов'),
                ),
              ];
            }

            return state.history.map(
              (query) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () {
                  controller.closeView(query);
                  unawaited(ref.read(searchControllerProvider.notifier).search(query));
                },
              ),
            );
          },
          viewLeading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _searchController.closeView(null);
            },
          ),
          barLeading: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          viewTrailing: [
            if (state.history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Очистить историю поиска',
                onPressed: () {
                  unawaited(ref.read(searchControllerProvider.notifier).clearHistory());
                },
              ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(searchControllerProvider.notifier).clearResults();
              },
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildFilters(context, state),
          if (state.isLoading && state.books.isEmpty) const LinearProgressIndicator(),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Ошибка: ${state.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _buildResults(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, SearchState state) {
    final filters = state.filters;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Фильтры',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Все'),
                  selected: filters.format == null,
                  onSelected: (_) => _setFormatFilter(null),
                ),
                ...BookFormat.values.map(
                  (format) => FilterChip(
                    label: Text(format.name.toUpperCase()),
                    selected: filters.format == format,
                    onSelected: (selected) => _setFormatFilter(selected ? format : null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _genreController,
                    decoration: const InputDecoration(
                      labelText: 'Жанр',
                      hintText: 'Например: фантастика',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      _debounceTimer?.cancel();
                      _setGenreFilter(value);
                    },
                    onChanged: (value) {
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        _setGenreFilter(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _languageController,
                    decoration: const InputDecoration(
                      labelText: 'Язык',
                      hintText: 'Например: ru',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      _debounceTimer?.cancel();
                      _setLanguageFilter(value);
                    },
                    onChanged: (value) {
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                        _setLanguageFilter(value);
                      });
                    },
                  ),
                ),
                if (filters.hasFilters)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Сбросить фильтры',
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    if (state.books.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Начните поиск',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final useGrid = !context.isCompact;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          unawaited(ref.read(searchControllerProvider.notifier).loadMore());
        }
        return false;
      },
      child: useGrid
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: state.books.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.books.length) {
                  return const Card(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final book = state.books[index];
                return BookCard(
                  key: ValueKey(book.id),
                  book: book,
                  onTap: () => unawaited(context.push('/reader/${book.id}')),
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.books.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.books.length) {
                  return const Skeletonizer(
                    child: Column(
                      children: [
                        Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Bone.circle(size: 48),
                            title: Bone.text(words: 3),
                            subtitle: Bone.text(words: 2),
                          ),
                        ),
                        Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Bone.circle(size: 48),
                            title: Bone.text(words: 3),
                            subtitle: Bone.text(words: 2),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final book = state.books[index];
                return BookListItem(
                  book: book,
                  onTap: () => unawaited(context.push('/reader/${book.id}')),
                );
              },
            ),
    );
  }
}

class BookListItem extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;

  const BookListItem({super.key, required this.book, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 64,
          child: BookCoverImage(book: book, width: 48, height: 64),
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.authorIds.isNotEmpty)
              Text(
                book.authorIds.join(', '),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (book.availableFormats.isNotEmpty)
              Wrap(
                spacing: 4,
                children: book.availableFormats
                    .map(
                      (f) => Chip(
                        label: Text(
                          f.name.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}

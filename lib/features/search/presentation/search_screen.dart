import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'search_controller.dart';
import '../../../shared/models/book.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final SearchController _searchController = SearchController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
      ref.read(searchControllerProvider.notifier).search(value.trim());
    });
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
              ref.read(searchControllerProvider.notifier).search(value.trim());
            }
          },
          suggestionsBuilder: (context, controller) {
            return [];
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
          if (state.isLoading && state.books.isEmpty)
            const LinearProgressIndicator(),
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

  Widget _buildResults(BuildContext context, SearchState state) {
    if (state.books.isEmpty && !state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Начните поиск', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          unawaited(
              ref.read(searchControllerProvider.notifier).loadMore());
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.books.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.books.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final book = state.books[index];
          return BookListItem(
            book: book,
            onTap: () {
              context.push('/reader/${book.id}');
            },
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
        leading: book.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  book.coverUrl!,
                  width: 48,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 64,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.book, size: 24),
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.book,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
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
                    .map((f) => Chip(
                          label: Text(
                            f.name.toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
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

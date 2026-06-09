import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/models/book.dart';
import '../data/catalog_repository_impl.dart';

part 'catalog_screen.g.dart';

@riverpod
Future<List<String>> categories(Ref ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.getCategories();
}

@riverpod
Future<List<Book>> popularBooks(Ref ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.getPopularBooks();
}

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final popularAsync = ref.watch(popularBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          categoriesAsync.when(
            data: (List<String> categories) => _buildCategories(context, categories),
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, _) => SizedBox(
              height: 100,
              child: Center(child: Text('Ошибка: $e')),
            ),
          ),
          const Divider(),
          popularAsync.when(
            data: (List<Book> books) => _buildPopularBooks(context, books),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, _) => SizedBox(
              height: 200,
              child: Center(child: Text('Ошибка: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, List<String> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Категории',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 100,
                  child: Center(
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularBooks(BuildContext context, List<Book> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Популярное',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Card(
                margin: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: book.coverUrl != null
                            ? Image.network(
                                book.coverUrl!,
                                width: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.book),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.book),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

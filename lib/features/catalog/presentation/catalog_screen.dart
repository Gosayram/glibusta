import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/error_state_widget.dart';
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(categoriesAsync.isLoading ? 'cat_loading' : categoriesAsync.hasError ? 'cat_error' : 'cat_data_${categoriesAsync.value?.length ?? 0}'),
              child: categoriesAsync.when(
                data: (List<String> categories) => _buildCategories(context, categories),
                loading: () => SizedBox(
                  height: 100,
                  child: Skeletonizer(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (_, _) => const Card(
                        margin: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 100,
                          child: Center(child: Bone.text(words: 1)),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (Object e, _) => SizedBox(
                  height: 100,
                  child: ErrorStateWidget(
                    message: 'Не удалось загрузить категории',
                    details: e.toString(),
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(popularAsync.isLoading ? 'pop_loading' : popularAsync.hasError ? 'pop_error' : 'pop_data_${popularAsync.value?.length ?? 0}'),
              child: popularAsync.when(
                data: (List<Book> books) => _buildPopularBooks(context, ref, books),
                loading: () => SizedBox(
                  height: 200,
                  child: Skeletonizer(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: 6,
                      itemBuilder: (_, _) => const Card(
                        child: ListTile(
                          leading: Bone.circle(size: 48),
                          title: Bone.text(words: 3),
                          subtitle: Bone.text(words: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (Object e, _) => SizedBox(
                  height: 200,
                  child: ErrorStateWidget(
                    message: 'Не удалось загрузить популярные книги',
                    details: e.toString(),
                    onRetry: () => ref.invalidate(popularBooksProvider),
                  ),
                ),
              ),
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

  Widget _buildPopularBooks(BuildContext context, WidgetRef ref, List<Book> books) {
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
          height: 240,
          child: FutureBuilder<Map<String, bool>>(
            future: _getDownloadStatusMap(ref, books),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Skeletonizer(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: 4,
                    itemBuilder: (_, _) => const Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Bone.square()),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Bone.text(words: 3),
                                SizedBox(height: 4),
                                Bone.text(words: 2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final downloadedMap = snapshot.data ?? {};

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  // Determine grid layout based on width
                  if (width < AppBreakpoints.compact) {
                    // Phone: 2 columns
                    return GridView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _buildBookCard(context, book, isDownloaded: downloadedMap[book.id]);
                      },
                    );
                  } else if (width < AppBreakpoints.expanded) {
                    // Tablet: 3-4 columns
                    final crossAxisCount = (width / 180).floor().clamp(3, 4);
                    return GridView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _buildBookCard(context, book, isDownloaded: downloadedMap[book.id]);
                      },
                    );
                  } else {
                    // Desktop: adaptive card width (180-220px)
                    return GridView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _buildBookCard(context, book, isDownloaded: downloadedMap[book.id]);
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Map<String, bool>> _getDownloadStatusMap(WidgetRef ref, List<Book> books) async {
    final bookIds = books.map((book) => book.id).toList();
    final database = ref.read(databaseProvider);
    final downloadedMap = <String, bool>{};
    if (bookIds.isNotEmpty) {
      final downloadRows = await (database.select(
        database.downloads,
      )..where((tbl) => tbl.bookId.isIn(bookIds))).get();
      for (final row in downloadRows) {
        // Consider a book downloaded if status is completed
        downloadedMap[row.bookId] = row.status == DownloadStatusDb.completed;
      }
    }
    return downloadedMap;
  }

  Widget _buildBookCard(BuildContext context, Book book, {bool? isDownloaded}) {
    return Semantics(
      label: 'Книга: ${book.title}',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: book.coverUrl != null
                      ? Image.network(
                          book.coverUrl!,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Download status indicator
            if (isDownloaded == true)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.download_done,
                  size: 16,
                  color: Colors.green,
                ),
              )
            else if (isDownloaded == false)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.cloud_download_outlined,
                  size: 16,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

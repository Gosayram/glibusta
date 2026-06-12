import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/book_card.dart';
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(popularBooksProvider);
        },
        child: _RestorableListView(
          restorationId: 'catalog-scroll',
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(
                  categoriesAsync.isLoading
                      ? 'cat_loading'
                      : categoriesAsync.hasError
                      ? 'cat_error'
                      : 'cat_data_${categoriesAsync.value?.length ?? 0}',
                ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAccessTile(
                      icon: Icons.new_releases_outlined,
                      label: 'Новые',
                      onTap: () => context.push('/recent'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessTile(
                      icon: Icons.category_outlined,
                      label: 'Жанры',
                      onTap: () => context.push('/genres'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessTile(
                      icon: Icons.trending_up,
                      label: 'Популярные',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(
                  popularAsync.isLoading
                      ? 'pop_loading'
                      : popularAsync.hasError
                      ? 'pop_error'
                      : 'pop_data_${popularAsync.value?.length ?? 0}',
                ),
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
                        return BookCard(
                          key: ValueKey(book.id),
                          book: book,
                          isDownloaded: downloadedMap[book.id],
                        );
                      },
                    );
                  } else if (width < AppBreakpoints.medium) {
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
                        return BookCard(
                          key: ValueKey(book.id),
                          book: book,
                          isDownloaded: downloadedMap[book.id],
                        );
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
                        return BookCard(
                          key: ValueKey(book.id),
                          book: book,
                          isDownloaded: downloadedMap[book.id],
                        );
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
}

class _RestorableListView extends StatefulWidget {
  final String restorationId;
  final List<Widget> children;

  const _RestorableListView({
    required this.restorationId,
    required this.children,
  });

  @override
  State<_RestorableListView> createState() => _RestorableListViewState();
}

class _RestorableListViewState extends State<_RestorableListView> with RestorationMixin {
  final RestorableDouble _offset = RestorableDouble(0);
  ScrollController? _controller;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool restoredFromOldBucket) {
    registerForRestoration(_offset, 'scroll_offset');
  }

  @override
  void dispose() {
    _controller?.removeListener(_saveOffset);
    _controller?.dispose();
    _offset.dispose();
    super.dispose();
  }

  ScrollController _getController() {
    _controller ??= ScrollController(
      initialScrollOffset: _offset.value,
      keepScrollOffset: false,
    )..addListener(_saveOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    return _controller!;
  }

  void _saveOffset() {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    _offset.value = controller.position.pixels;
  }

  void _restoreOffset() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.hasClients) return;
    final maxOffset = controller.position.maxScrollExtent;
    final offset = _offset.value.clamp(0.0, maxOffset);
    if (offset > 0 && (controller.position.pixels - offset).abs() > 1) {
      controller.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(controller: _getController(), children: widget.children);
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_card_skeleton.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/restorable_scroll_view.dart';
import '../../search/data/flibusta_models.dart';
import '../../search/data/flibusta_source.dart';

part 'catalog_screen.g.dart';

// ponytail: minimal cache entry, same ttl as the old CatalogRepositoryImpl
class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;
  _CacheEntry(this.data, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

const _cacheTtl = Duration(minutes: 10);
final _categoriesCache = <String, _CacheEntry<List<SearchGenreItem>>>{};
final _booksCache = <String, _CacheEntry<List<Book>>>{};

@riverpod
Future<List<SearchGenreItem>> categories(Ref ref) async {
  final cached = _categoriesCache['categories'];
  if (cached != null && !cached.isExpired) return cached.data;

  final apiClient = ref.watch(flibustaSourceProvider);
  try {
    final response = await apiClient.getGenreList();
    final result = response.genres;
    _categoriesCache['categories'] = _CacheEntry(result, DateTime.now().add(_cacheTtl));
    return result;
  } on Object catch (e) {
    AppLogger().warning('Genre list failed, using defaults: $e', name: 'Catalog');
    return const [
      SearchGenreItem(id: 'sf', name: 'Фантастика'),
      SearchGenreItem(id: 'detive', name: 'Детективы'),
      SearchGenreItem(id: 'love', name: 'Романы'),
      SearchGenreItem(id: 'science', name: 'Научная литература'),
      SearchGenreItem(id: 'history', name: 'История'),
      SearchGenreItem(id: 'adventures', name: 'Приключения'),
    ];
  }
}

@riverpod
Future<List<Book>> popularBooks(Ref ref) async {
  final cached = _booksCache['popular'];
  if (cached != null && !cached.isExpired) return cached.data;

  final apiClient = ref.watch(flibustaSourceProvider);
  try {
    final result = await apiClient.getPopularBooks();
    final rawBase = apiClient.dio.options.baseUrl;
    final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
    final books = result.books
        .map(
          (item) => Book(
            id: item.id,
            title: item.name,
            authorIds: item.authors.map((a) => a.id).toList(),
            authorNames: item.authors.map((a) => a.name).toList(),
            genreIds: const [],
            description: null,
            coverUrl: null,
            publishDate: null,
            availableFormats: const [],
            source: BookSourceInfo(
              sourceId: 'flibusta-api',
              sourceUrl: '$base/b/${item.id}',
            ),
          ),
        )
        .toList();
    _booksCache['popular'] = _CacheEntry(books, DateTime.now().add(_cacheTtl));
    return books;
  } on Object catch (e) {
    AppLogger().warning('Popular books query failed: $e', name: 'Catalog', error: e);
    return const [];
  }
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  Future<Map<String, bool>>? _downloadStatusFuture;
  List<Book> _lastBooks = const [];
  String? _lastLoggedError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final popularAsync = ref.watch(popularBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogTitle),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(popularBooksProvider);
        },
        child: RestorableListView(
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
                  data: (List<SearchGenreItem> categories) => _buildCategories(context, categories),
                  loading: () => SizedBox(
                    height: 120,
                    child: Skeletonizer.zone(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: 6,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, _) => const Bone(width: 80, height: 32),
                      ),
                    ),
                  ),
                  error: (Object e, _) => SizedBox(
                    height: 100,
                    child: ErrorStateWidget(
                      message: l10n.categoriesLoadError,
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
                      label: l10n.newLabel,
                      onTap: () => context.push('/recent'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessTile(
                      icon: Icons.category_outlined,
                      label: l10n.genresTitle,
                      onTap: () => context.push('/genres'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ponytail: popular books already shown inline below — no separate screen
                  Expanded(
                    child: _QuickAccessTile(
                      icon: Icons.trending_up,
                      label: l10n.popularLabel,
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
                    height: 300,
                    child: Skeletonizer.zone(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: 6,
                        itemBuilder: (_, _) => const BookCardSkeleton(),
                      ),
                    ),
                  ),
                  error: (Object e, _) => SizedBox(
                    height: 200,
                    child: ErrorStateWidget(
                      message: l10n.recentBooksLoadError,
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

  Widget _buildCategories(BuildContext context, List<SearchGenreItem> categories) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.genresTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => context.push('/genres'),
                child: Text(l10n.allGenres),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length > 20 ? 20 : categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Padding(
                key: ValueKey('${category.id}-$index'),
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(category.name, style: const TextStyle(fontSize: 13)),
                  onPressed: () => context.push('/genre/${category.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularBooks(BuildContext context, WidgetRef ref, List<Book> books) {
    final l10n = AppLocalizations.of(context);
    if (!identical(books, _lastBooks)) {
      _lastBooks = books;
      _downloadStatusFuture = _getDownloadStatusMap(ref, books);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.popularSection,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 240,
          child: FutureBuilder<Map<String, bool>>(
            future: _downloadStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final errorStr = '${snapshot.error}';
                if (errorStr != _lastLoggedError) {
                  _lastLoggedError = errorStr;
                  AppLogger().warning(
                    '[Catalog] Failed to fetch download status: $errorStr',
                    name: 'Catalog',
                  );
                }
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Skeletonizer.zone(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: 4,
                    itemBuilder: (_, _) => const BookCardSkeleton(),
                  ),
                );
              }
              final downloadedMap = snapshot.data ?? {};

              return FocusTraversalGroup(
                child: LayoutBuilder(
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
                ),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../search/data/composite_source.dart';
import '../../search/data/flibusta_api_client.dart';
import '../../search/data/flibusta_models.dart';
import '../../search/domain/book_source.dart';
import '../domain/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final source = ref.watch(bookSourceProvider);
  final apiClient = ref.watch(flibustaApiClientProvider);
  return CatalogRepositoryImpl(source, apiClient);
});

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;
  _CacheEntry(this.data, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class CatalogRepositoryImpl implements CatalogRepository {
  final BookSource _source;
  final FlibustaApiClient _apiClient;
  final _logger = AppLogger();

  CatalogRepositoryImpl(this._source, this._apiClient);

  static const _cacheTtl = Duration(minutes: 10);
  final _categoriesCache = <String, _CacheEntry<List<SearchGenreItem>>>{};
  final _booksCache = <String, _CacheEntry<List<Book>>>{};

  @override
  Future<List<SearchGenreItem>> getCategories() async {
    final cached = _categoriesCache['categories'];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final response = await _apiClient.getGenreList();
      final result = response.genres;
      _categoriesCache['categories'] = _CacheEntry(result, DateTime.now().add(_cacheTtl));
      return result;
    } on Object catch (e) {
      _logger.warning('Genre list failed, using defaults: $e', name: 'Catalog');
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

  @override
  Future<List<Book>> getPopularBooks() async {
    final cached = _booksCache['popular'];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final result = await _apiClient.getPopularBooks();
      final rawBase = _apiClient.dio.options.baseUrl;
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
      _logger.warning('Popular books query failed: $e', name: 'Catalog', error: e);
      return const [];
    }
  }

  @override
  Future<List<Book>> getRecentBooks() async {
    final cached = _booksCache['recent'];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final result = await _apiClient.getRecentBooks();
      final rawBase = _apiClient.dio.options.baseUrl;
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
      _booksCache['recent'] = _CacheEntry(books, DateTime.now().add(_cacheTtl));
      return books;
    } on Object catch (e) {
      _logger.warning('Recent books query failed: $e', name: 'Catalog', error: e);
      return const [];
    }
  }

  @override
  Future<List<Book>> getBooksByCategory(String category) async {
    final cached = _booksCache['cat:$category'];
    if (cached != null && !cached.isExpired) return cached.data;

    final query = SearchQuery(query: category);
    try {
      final result = await _source.searchBooks(query);
      _booksCache['cat:$category'] = _CacheEntry(result.books, DateTime.now().add(_cacheTtl));
      return result.books;
    } on Object catch (e) {
      _logger.warning('Category query failed ($category): $e', name: 'Catalog', error: e);
      return const [];
    }
  }
}

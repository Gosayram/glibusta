import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../search/data/composite_source.dart';
import '../../search/data/flibusta_api_client.dart';
import '../../search/domain/book_source.dart';
import '../domain/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final source = ref.watch(bookSourceProvider);
  final apiClient = ref.watch(flibustaApiClientProvider);
  return CatalogRepositoryImpl(source, apiClient);
});

class CatalogRepositoryImpl implements CatalogRepository {
  final BookSource _source;
  final FlibustaApiClient _apiClient;
  final _logger = AppLogger();

  CatalogRepositoryImpl(this._source, this._apiClient);

  @override
  Future<List<String>> getCategories() async {
    try {
      final response = await _apiClient.getGenreList();
      return response.genres.map((g) => g.name).toList();
    } on Object catch (e) {
      _logger.warning('Genre list failed, using defaults: $e', name: 'Catalog');
      return const [
        'Фантастика',
        'Детективы',
        'Романы',
        'Научная литература',
        'История',
        'Приключения',
      ];
    }
  }

  @override
  Future<List<Book>> getPopularBooks() async {
    try {
      final result = await _apiClient.getPopularBooks();
      final rawBase = _apiClient.dio.options.baseUrl;
      final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
      return result.books
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
    } on Object catch (e) {
      _logger.warning('Popular books query failed: $e', name: 'Catalog', error: e);
      return const [];
    }
  }

  @override
  Future<List<Book>> getRecentBooks() async {
    try {
      final result = await _apiClient.getRecentBooks();
      final rawBase = _apiClient.dio.options.baseUrl;
      final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
      return result.books
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
    } on Object catch (e) {
      _logger.warning('Recent books query failed: $e', name: 'Catalog', error: e);
      return const [];
    }
  }

  @override
  Future<List<Book>> getBooksByCategory(String category) async {
    final query = SearchQuery(query: category);
    try {
      final result = await _source.searchBooks(query);
      return result.books;
    } on Object catch (e) {
      _logger.warning('Category query failed ($category): $e', name: 'Catalog', error: e);
      return const [];
    }
  }
}

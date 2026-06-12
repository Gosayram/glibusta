import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../search/data/composite_source.dart';
import '../../search/domain/book_source.dart';
import '../domain/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final source = ref.watch(bookSourceProvider);
  return CatalogRepositoryImpl(source);
});

class CatalogRepositoryImpl implements CatalogRepository {
  final BookSource _source;
  final _logger = AppLogger();

  CatalogRepositoryImpl(this._source);

  @override
  Future<List<String>> getCategories() async {
    return const [
      'Фантастика',
      'Детективы',
      'Романы',
      'Научная литература',
      'История',
      'Приключения',
    ];
  }

  @override
  Future<List<Book>> getPopularBooks() async {
    final query = const SearchQuery(query: '');
    try {
      final result = await _source.searchBooks(query);
      return result.books;
    } on Object catch (e) {
      _logger.warning('Popular books query failed: $e', name: 'Catalog', error: e);
      return const [];
    }
  }

  @override
  Future<List<Book>> getRecentBooks() async {
    final query = const SearchQuery(query: '');
    try {
      final result = await _source.searchBooks(query);
      return result.books;
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

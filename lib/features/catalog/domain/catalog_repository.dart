import '../../../shared/models/book.dart';

abstract class CatalogRepository {
  Future<List<String>> getCategories();
  Future<List<Book>> getPopularBooks();
  Future<List<Book>> getRecentBooks();
  Future<List<Book>> getBooksByCategory(String category);
}

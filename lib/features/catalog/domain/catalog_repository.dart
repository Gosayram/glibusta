import '../../../shared/models/book.dart';
import '../../search/data/flibusta_models.dart';

abstract class CatalogRepository {
  Future<List<SearchGenreItem>> getCategories();
  Future<List<Book>> getPopularBooks();
  Future<List<Book>> getRecentBooks();
  Future<List<Book>> getBooksByCategory(String category);
}

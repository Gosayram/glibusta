import '../../../shared/models/book.dart';

enum BookSortField { addedAt, title, progress }

abstract class BookRepository {
  Future<List<Book>> getAllBooks();
  Future<List<Book>> getPagedBooks({
    required int limit,
    int offset = 0,
    BookSortField sortField = BookSortField.addedAt,
    bool ascending = false,
    String? formatFilter,
  });
  Future<List<Book>> searchBooksPaged(
    String query, {
    required int limit,
    int offset = 0,
    String? formatFilter,
  });
  Future<List<Book>> getBooksByIds(List<String> ids);
  Future<List<Book>> searchBooks(String query);
  Future<List<Book>> getBooksWithProgress();
  Future<Book?> getBookById(String id);
  Future<void> saveBook(Book book);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Future<bool> isBookInLibrary(String id);
}

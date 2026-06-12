import '../../../shared/models/book.dart';

abstract class BookRepository {
  Future<List<Book>> getAllBooks();
  Future<List<Book>> getBooksWithProgress();
  Future<Book?> getBookById(String id);
  Future<void> saveBook(Book book);
  Future<void> deleteBook(String id);
  Future<bool> isBookInLibrary(String id);
}

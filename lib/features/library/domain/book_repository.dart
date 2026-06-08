import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';

abstract class BookRepository {
  Future<List<Book>> getLocalLibrary();
  Future<void> saveBook(Book book);
  Future<void> deleteBook(String bookId);
  Future<void> saveDownloadTask(DownloadTask task);
  Future<List<DownloadTask>> getDownloadTasks();
}
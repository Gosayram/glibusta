import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';

abstract class BookDetailsRepository {
  Future<BookDetails> getBookDetails(String bookId);
  Future<List<BookFormat>> getAvailableFormats(String bookId);
  Future<String> getDownloadUrl(String bookId, BookFormat format);
}

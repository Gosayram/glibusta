import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';

abstract class SearchBooksUseCase {
  Future<SearchResultPage> call(SearchQuery query);
}

abstract class GetBookDetailsUseCase {
  Future<BookDetails> call(String bookId);
}

abstract class GetAvailableFormatsUseCase {
  Future<List<BookFormat>> call(String bookId);
}

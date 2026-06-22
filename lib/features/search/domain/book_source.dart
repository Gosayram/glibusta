import 'package:dio/dio.dart';

import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';

abstract class BookSource {
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken});

  Future<SearchAuthorsResultPage> searchAuthors(SearchQuery query, {CancelToken? cancelToken});

  Future<BookDetails> getBookDetails(String bookId);

  Future<List<BookFormat>> getAvailableFormats(String bookId);

  Future<String> getDownloadUrl(String bookId, BookFormat format);
}

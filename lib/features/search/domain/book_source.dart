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

class MockBookSource implements BookSource {
  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) async {
    return SearchResultPage(
      books: const [],
      totalCount: 0,
      currentPage: query.page,
      totalPages: 0,
      hasNextPage: false,
    );
  }

  @override
  Future<SearchAuthorsResultPage> searchAuthors(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) async {
    return const SearchAuthorsResultPage(authors: []);
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    return BookDetails(
      book: Book(
        id: bookId,
        title: 'Mock Book',
        authorIds: const [],
        genreIds: const [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: const [BookFormat.fb2, BookFormat.epub, BookFormat.txt, BookFormat.mobi],
        source: const BookSourceInfo(sourceId: 'mock', sourceUrl: ''),
      ),
      description: 'Mock description',
      availableFormats: const [BookFormat.fb2, BookFormat.epub, BookFormat.txt, BookFormat.mobi],
      downloadUrls: const [],
    );
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    return const [BookFormat.fb2, BookFormat.epub, BookFormat.txt, BookFormat.mobi];
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    return 'https://example.com/download/$bookId.$format';
  }
}

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';
import 'flibusta_api_client.dart';

part 'flibusta_api_source.g.dart';

@riverpod
FlibustaApiSource flibustaApiSource(Ref ref) {
  final client = ref.watch(flibustaApiClientProvider);
  return FlibustaApiSource(client);
}

class FlibustaApiSource extends BookSource {
  final FlibustaApiClient _client;

  FlibustaApiSource(this._client);

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) async {
    if (query.hasFilters) {
      return SearchResultPage(
        books: const [],
        totalCount: 0,
        currentPage: query.page,
        totalPages: 0,
        hasNextPage: false,
      );
    }

    try {
      final result = await _client.searchBooksByNameOpds(
        query.query,
        page: query.page,
        cancelToken: cancelToken,
      );

      final rawBase = _client.dio.options.baseUrl;
      final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
      final books = result.books
          .map(
            (item) => Book(
              id: item.id,
              title: item.name,
              authorIds: const [],
              genreIds: const [],
              description: null,
              coverUrl: null,
              publishDate: null,
              availableFormats: const [],
              source: BookSourceInfo(
                sourceId: 'flibusta-api',
                sourceUrl: '$base/b/${item.id}',
              ),
            ),
          )
          .toList();

      return SearchResultPage(
        books: books,
        totalCount: books.length,
        currentPage: query.page,
        totalPages: books.isEmpty ? 0 : 1,
        hasNextPage: books.length >= 20,
      );
    } on Object catch (e) {
      throw Exception('Failed to search books: $e');
    }
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    try {
      final result = await _client.getBookDetails(bookId);
      final baseUrl = _client.dio.options.baseUrl;
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final book = Book(
        id: result.id,
        title: result.title,
        authorIds: result.authors,
        authorNames: result.authors,
        genreIds: const [],
        description: result.description,
        coverUrl: result.coverUrl != null ? '$normalizedBase${result.coverUrl}' : null,
        publishDate: null,
        availableFormats: _parseFormats(result.formats),
        source: BookSourceInfo(
          sourceId: 'flibusta-api',
          sourceUrl: '$normalizedBase/b/$bookId',
        ),
      );

      return BookDetails(
        book: book,
        description: result.description,
        availableFormats: _parseFormats(result.formats),
        downloadUrls: result.formats.map((f) => '$normalizedBase/b/$bookId/download/$f').toList(),
      );
    } on Object catch (e) {
      throw Exception('Failed to get book details: $e');
    }
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    final details = await getBookDetails(bookId);
    return details.availableFormats;
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    return _client.getDownloadUrl(bookId, format.name);
  }

  List<BookFormat> _parseFormats(List<String> formatStrings) {
    final formats = <BookFormat>[];
    for (final f in formatStrings) {
      final lower = f.toLowerCase();
      if (lower.contains('fb2')) {
        formats.add(BookFormat.fb2);
      } else if (lower.contains('epub')) {
        formats.add(BookFormat.epub);
      } else if (lower.contains('txt')) {
        formats.add(BookFormat.txt);
      } else if (lower.contains('pdf')) {
        formats.add(BookFormat.pdf);
      }
    }
    return formats;
  }
}

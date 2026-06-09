import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';
import 'flibusta_api_source.dart';
import 'flibusta_source.dart';

final bookSourceProvider = Provider<BookSource>((ref) {
  final sources = <BookSource>[
    ref.watch(flibustaApiSourceProvider),
    ref.watch(flibustaSourceProvider),
  ];
  return CompositeBookSource(sources);
});

class CompositeBookSource extends BookSource {
  final List<BookSource> sources;

  CompositeBookSource(this.sources);

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final result = await source.searchBooks(query);
        if (result.books.isNotEmpty) return result;
      } on AppFailure catch (e) {
        errors.add(e);
      } on Object catch (e) {
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    if (errors.isNotEmpty) {
      throw SourceUnavailableFailure(
        'All sources failed: ${errors.map((e) => e.message).join('; ')}',
      );
    }
    return SearchResultPage(
      books: const [],
      totalCount: 0,
      currentPage: query.page,
      totalPages: 0,
      hasNextPage: false,
    );
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        return await source.getBookDetails(bookId);
      } on AppFailure catch (e) {
        errors.add(e);
      } on Object catch (e) {
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    throw SourceUnavailableFailure(
      'All sources failed for book $bookId: ${errors.map((e) => e.message).join('; ')}',
    );
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final formats = await source.getAvailableFormats(bookId);
        if (formats.isNotEmpty) return formats;
      } on AppFailure catch (e) {
        errors.add(e);
      } on Object catch (e) {
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    return const [];
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final url = await source.getDownloadUrl(bookId, format);
        if (url.isNotEmpty) return url;
      } on AppFailure catch (e) {
        errors.add(e);
      } on Object catch (e) {
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    throw SourceUnavailableFailure(
      'No download URL found for book $bookId format ${format.name}',
    );
  }
}

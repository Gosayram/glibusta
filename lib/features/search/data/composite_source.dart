import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../../shared/models/download_task.dart';
import '../domain/book_source.dart';
import 'flibusta_source.dart';

final compositeSourceProvider = Provider<CompositeBookSource>((ref) {
  final sources = <BookSource>[
    ref.watch(flibustaSourceProvider),
  ];
  return CompositeBookSource(sources);
});

class CompositeBookSource extends BookSource {
  final List<BookSource> sources;

  CompositeBookSource(this.sources);

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query) async {
    for (final source in sources) {
      try {
        final result = await source.searchBooks(query);
        if (result.books.isNotEmpty) return result;
      } catch (_) {}
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
    for (final source in sources) {
      try {
        return await source.getBookDetails(bookId);
      } catch (_) {}
    }
    return BookDetails(
      book: Book(
        id: bookId,
        title: '',
        authorIds: const [],
        genreIds: const [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: const [],
        source: BookSourceInfo(sourceId: 'composite', sourceUrl: ''),
      ),
      description: null,
      availableFormats: const [],
      downloadUrls: const [],
    );
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    for (final source in sources) {
      try {
        return await source.getAvailableFormats(bookId);
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    for (final source in sources) {
      try {
        return await source.getDownloadUrl(bookId, format);
      } catch (_) {}
    }
    return '';
  }
}
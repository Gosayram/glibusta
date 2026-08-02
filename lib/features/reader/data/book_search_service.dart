import 'dart:async';

import '../../../src/rust/api/api/api.dart' as rust_api;
import 'parsers/normalized_book.dart';

class BookSearchResult {
  final int chapterIndex;
  final int paragraphIndex;
  final String chapterTitle;
  final String matchText;
  final String beforeContext;
  final String afterContext;

  const BookSearchResult({
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.chapterTitle,
    required this.matchText,
    required this.beforeContext,
    required this.afterContext,
  });
}

class BookSearchService {
  final NormalizedBook _book;
  final String _filePath;

  int _searchGeneration = 0;

  BookSearchService(this._book, this._filePath);

  /// Stable identifier used to scope device-local reader search history.
  String get bookId => _book.id;

  int get totalParagraphs => _book.chapters.fold(0, (sum, c) => sum + c.blocks.length);

  String _chapterTitle(int chapterIndex) {
    final titles = _book.chapters.where((c) => c.index == chapterIndex).map((c) => c.title);
    return titles.isNotEmpty ? titles.first : '';
  }

  Future<List<BookSearchResult>> search(
    String query, {
    int maxResults = 50,
    int? chapterIndex,
    bool matchCase = false,
    bool useRegex = false,
    bool wholeWord = false,
  }) async {
    if (query.trim().isEmpty) return const [];
    final gen = ++_searchGeneration;

    final matches = await rust_api.searchInBook(
      path: _filePath,
      query: query,
      limit: BigInt.from(maxResults),
    );

    if (gen != _searchGeneration) return const [];

    final results = <BookSearchResult>[];
    for (final m in matches) {
      if (chapterIndex != null && m.chapterIndex != chapterIndex) continue;
      results.add(
        BookSearchResult(
          chapterIndex: m.chapterIndex,
          paragraphIndex: m.blockIndex,
          chapterTitle: _chapterTitle(m.chapterIndex),
          matchText: m.preview,
          beforeContext: '',
          afterContext: '',
        ),
      );
    }
    return results;
  }

  void cancelPending() {
    _searchGeneration++;
  }

  List<String> suggestions(String prefix, {int maxSuggestions = 8}) => const [];
}

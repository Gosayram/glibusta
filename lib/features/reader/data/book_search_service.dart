import 'dart:async';
import 'dart:math';

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

      var before = '';
      var after = '';
      try {
        final ch = _book.chapters.where((c) => c.index == m.chapterIndex);
        if (ch.isNotEmpty) {
          final bl = ch.first.blocks.where((b) => b.index == m.blockIndex);
          if (bl.isNotEmpty) {
            final ctx = _extractContext(
              bl.first.text,
              m.spanStart.toInt(),
              m.spanEnd.toInt(),
            );
            before = ctx.before;
            after = ctx.after;
          }
        }
      } on Object catch (_) {
        // Fallback: leave context empty rather than crashing the search.
      }

      results.add(
        BookSearchResult(
          chapterIndex: m.chapterIndex,
          paragraphIndex: m.blockIndex,
          chapterTitle: _chapterTitle(m.chapterIndex),
          matchText: m.preview,
          beforeContext: before,
          afterContext: after,
        ),
      );
    }
    return results;
  }

  void cancelPending() {
    _searchGeneration++;
  }

  List<String> suggestions(String prefix, {int maxSuggestions = 8}) => const [];

  /// Converts a UTF-8 byte offset (from Rust) to a Dart string character index.
  static int _byteToCharOffset(String text, int byteOffset) {
    var charIndex = 0;
    var byteCount = 0;
    for (final rune in text.runes) {
      final size = rune < 0x80 ? 1 : (rune < 0x800 ? 2 : (rune < 0x10000 ? 3 : 4));
      if (byteCount + size > byteOffset) break;
      byteCount += size;
      charIndex++;
    }
    return charIndex;
  }

  /// Extracts surrounding context from the paragraph text around a match.
  static ({String before, String after}) _extractContext(
    String paragraphText,
    int spanStartByte,
    int spanEndByte,
  ) {
    final start = _byteToCharOffset(paragraphText, spanStartByte);
    final end = _byteToCharOffset(paragraphText, spanEndByte);
    const ctxLen = 120;
    final before = start > 0 ? paragraphText.substring(max(0, start - ctxLen), start) : '';
    final after = end < paragraphText.length
        ? paragraphText.substring(end, min(paragraphText.length, end + ctxLen))
        : '';
    return (before: before, after: after);
  }
}

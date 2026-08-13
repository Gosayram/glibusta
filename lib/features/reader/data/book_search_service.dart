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

  String get bookId => _book.id;

  int get totalParagraphs => _book.chapters.fold(
      0, (sum, c) => sum + c.blocks.where((b) => b.text.trim().isNotEmpty).length);

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

    // ponytail: Rust searchInBook does case-insensitive substring only.
    // For matchCase/useRegex/wholeWord, use the in-memory path directly.
    final hasOptions = matchCase || useRegex || wholeWord;

    List<_RustMatch> matches;
    if (hasOptions) {
      matches = _searchInMemory(
        query,
        maxResults,
        matchCase: matchCase,
        useRegex: useRegex,
        wholeWord: wholeWord,
      );
    } else {
      try {
        final rawMatches = await rust_api.searchInBook(
          path: _filePath,
          query: query,
          limit: BigInt.from(maxResults),
        );
        matches = rawMatches
            .map((m) => _RustMatch(
                  chapterIndex: m.chapterIndex,
                  blockIndex: m.blockIndex,
                  spanStart: m.spanStart.toInt(),
                  spanEnd: m.spanEnd.toInt(),
                  preview: m.preview,
                ))
            .toList();
      } on Object catch (_) {
        matches = _searchInMemory(
          query,
          maxResults,
          matchCase: matchCase,
          useRegex: useRegex,
          wholeWord: wholeWord,
        );
      }
    }

    if (gen != _searchGeneration) return const [];

    final results = <BookSearchResult>[];
    for (final m in matches) {
      if (chapterIndex != null && m.chapterIndex != chapterIndex) continue;

      var before = '';
      var after = '';
      try {
        final ch = _book.chapters.where((c) => c.index == m.chapterIndex);
        if (ch.isNotEmpty) {
          final blocks = ch.first.blocks;
          final blockIdx = blocks.indexWhere((b) => b.index == m.blockIndex);
          if (blockIdx != -1) {
            if (blockIdx > 0) {
              before = blocks[blockIdx - 1].text;
            }
            if (blockIdx < blocks.length - 1) {
              after = blocks[blockIdx + 1].text;
            }
          }
        }
      } on Object catch (_) {}

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

  List<String> suggestions(String prefix, {int maxSuggestions = 8}) {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) return const [];
    final lower = trimmed.toLowerCase();
    final seen = <String>{};
    final results = <String>[];

    for (final chapter in _book.chapters) {
      for (final block in chapter.blocks) {
        final text = block.text;
        if (text.isEmpty) continue;
        final lowerText = text.toLowerCase();
        var idx = 0;
        while (idx < text.length && results.length < maxSuggestions) {
          final found = lowerText.indexOf(lower, idx);
          if (found == -1) break;

          final matchEnd = found + trimmed.length;
          final start = found > 30 ? found - 30 : 0;
          final end = matchEnd + 30 < text.length ? matchEnd + 30 : text.length;
          final snippet = (start > 0 ? '…' : '') +
              text.substring(start, end) +
              (end < text.length ? '…' : '');

          if (seen.add(snippet)) {
            results.add(snippet);
          }
          idx = matchEnd;
        }
        if (results.length >= maxSuggestions) break;
      }
      if (results.length >= maxSuggestions) break;
    }
    return results;
  }

  List<_RustMatch> _searchInMemory(
    String query,
    int maxResults, {
    required bool matchCase,
    required bool useRegex,
    required bool wholeWord,
  }) {
    final results = <_RustMatch>[];
    RegExp? pattern;
    if (useRegex) {
      try {
        pattern = RegExp(query, caseSensitive: matchCase, multiLine: true);
      } on Object catch (_) {
        return results;
      }
    }
    final needle = matchCase ? query : query.toLowerCase();

    for (final chapter in _book.chapters) {
      for (final block in chapter.blocks) {
        if (block.text.isEmpty) continue;
        final text = block.text;
        final lowerText = matchCase ? text : text.toLowerCase();

        int? matchStart;
        int? matchEnd;

        if (pattern != null) {
          final m = pattern.firstMatch(text);
          if (m != null) {
            matchStart = m.start;
            matchEnd = m.end;
          }
        } else {
          final idx = lowerText.indexOf(needle);
          if (idx != -1) {
            matchStart = idx;
            matchEnd = idx + query.length;

            if (wholeWord) {
              final before = matchStart > 0 ? text[matchStart - 1] : ' ';
              final after = matchEnd < text.length ? text[matchEnd] : ' ';
              if (_isWordChar(before) || _isWordChar(after)) {
                matchStart = null;
                matchEnd = null;
              }
            }
          }
        }

        if (matchStart != null && matchEnd != null) {
          if (wholeWord && pattern != null) {
            final before = matchStart > 0 ? text[matchStart - 1] : ' ';
            final after = matchEnd < text.length ? text[matchEnd] : ' ';
            if (_isWordChar(before) || _isWordChar(after)) continue;
          }

          results.add(_RustMatch(
            chapterIndex: chapter.index,
            blockIndex: block.index,
            spanStart: matchStart,
            spanEnd: matchEnd,
            preview: text,
            areCharOffsets: true,
          ));
          if (results.length >= maxResults) return results;
        }
      }
    }
    return results;
  }

  // ponytail: \w is ASCII-only in Dart; use Unicode letter check for Cyrillic
  static final _wordCharRe = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  static bool _isWordChar(String c) => c.isNotEmpty && _wordCharRe.hasMatch(c);
}

class _RustMatch {
  final int chapterIndex;
  final int blockIndex;
  final int spanStart;
  final int spanEnd;
  final String preview;
  final bool areCharOffsets;

  const _RustMatch({
    required this.chapterIndex,
    required this.blockIndex,
    required this.spanStart,
    required this.spanEnd,
    required this.preview,
    this.areCharOffsets = false,
  });
}

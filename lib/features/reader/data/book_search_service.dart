import '../parsers/normalized_book.dart';

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
  final List<String> _paragraphs = [];
  final List<int> _chapterIndices = [];
  final List<int> _paragraphIndices = [];
  final List<String> _chapterTitles = [];

  BookSearchService(this._book) {
    _buildIndex();
  }

  void _buildIndex() {
    for (final chapter in _book.chapters) {
      for (final block in chapter.blocks) {
        if (block.text.trim().isEmpty) continue;
        _paragraphs.add(block.text);
        _chapterIndices.add(chapter.index);
        _paragraphIndices.add(block.index);
        _chapterTitles.add(chapter.title);
      }
    }
  }

  int get totalParagraphs => _paragraphs.length;

  List<BookSearchResult> search(String query, {int maxResults = 50}) {
    if (query.trim().isEmpty) return const [];
    final lowerQuery = query.toLowerCase();
    final results = <BookSearchResult>[];

    for (var i = 0; i < _paragraphs.length; i++) {
      final paragraph = _paragraphs[i];
      if (!paragraph.toLowerCase().contains(lowerQuery)) continue;

      final before = i > 0 ? _paragraphs[i - 1] : '';
      final after = i < _paragraphs.length - 1 ? _paragraphs[i + 1] : '';

      results.add(
        BookSearchResult(
          chapterIndex: _chapterIndices[i],
          paragraphIndex: _paragraphIndices[i],
          chapterTitle: _chapterTitles[i],
          matchText: paragraph,
          beforeContext: before,
          afterContext: after,
        ),
      );

      if (results.length >= maxResults) break;
    }

    return results;
  }

  List<String> suggestions(String prefix, {int maxSuggestions = 8}) {
    if (prefix.trim().isEmpty) return const [];
    final lowerPrefix = prefix.toLowerCase();
    final seen = <String>{};
    final suggestions = <String>[];

    for (final paragraph in _paragraphs) {
      final lower = paragraph.toLowerCase();
      final index = lower.indexOf(lowerPrefix);
      if (index < 0) continue;

      final start = index > 20 ? index - 20 : 0;
      final snippet = paragraph.substring(start).trim();
      final ellipsed = (start > 0 ? '…' : '') + snippet;
      if (seen.add(ellipsed)) {
        suggestions.add(ellipsed);
        if (suggestions.length >= maxSuggestions) break;
      }
    }

    return suggestions;
  }
}

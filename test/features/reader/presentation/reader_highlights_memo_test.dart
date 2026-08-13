import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

Map<int, List<TextHighlight>> buildChapterHighlights(
  List<TextHighlight>? highlights,
  List<TextHighlight>? lastSource,
  Map<int, List<TextHighlight>>? cached,
  void Function(List<TextHighlight>? source, Map<int, List<TextHighlight>> result) onCache,
) {
  if (identical(highlights, lastSource) && cached != null) {
    return cached;
  }
  final result = <int, List<TextHighlight>>{};
  if (highlights != null) {
    for (final h in highlights) {
      result.putIfAbsent(h.chapterIndex, () => []).add(h);
    }
  }
  onCache(highlights, result);
  return result;
}

TextHighlight _highlight({
  required String id,
  required int chapterIndex,
}) {
  return TextHighlight(
    id: id,
    bookId: 'book-1',
    chapterId: 'ch-$chapterIndex',
    chapterIndex: chapterIndex,
    blockIndex: 0,
    startOffset: 0,
    endOffset: 10,
    selectedText: 'text',
    color: '#FFFF00',
    decoration: '',
    isOrphaned: false,
    createdAt: DateTime(2025),
  );
}

void main() {
  group('buildChapterHighlights memoization', () {
    test('returns cached map when source list is identical', () {
      final source = [_highlight(id: '1', chapterIndex: 0)];
      List<TextHighlight>? cachedSource;
      Map<int, List<TextHighlight>>? cachedMap;

      final first = buildChapterHighlights(source, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });
      expect(first, hasLength(1));

      final second = buildChapterHighlights(source, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });

      expect(identical(first, second), isTrue);
    });

    test('rebuilds map when source list is a different object', () {
      final source1 = [_highlight(id: '1', chapterIndex: 0)];
      List<TextHighlight>? cachedSource;
      Map<int, List<TextHighlight>>? cachedMap;

      final first = buildChapterHighlights(source1, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });

      final source2 = [_highlight(id: '1', chapterIndex: 0)];
      final second = buildChapterHighlights(source2, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });

      expect(identical(first, second), isFalse);
      expect(first, equals(second));
    });

    test('handles null source', () {
      List<TextHighlight>? cachedSource;
      Map<int, List<TextHighlight>>? cachedMap;

      final first = buildChapterHighlights(null, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });
      expect(first, isEmpty);

      final second = buildChapterHighlights(null, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });
      expect(identical(first, second), isTrue);
    });

    test('groups highlights by chapter index', () {
      final source = [
        _highlight(id: '1', chapterIndex: 0),
        _highlight(id: '2', chapterIndex: 1),
        _highlight(id: '3', chapterIndex: 0),
      ];
      List<TextHighlight>? cachedSource;
      Map<int, List<TextHighlight>>? cachedMap;

      final result = buildChapterHighlights(source, cachedSource, cachedMap, (s, r) {
        cachedSource = s;
        cachedMap = r;
      });

      expect(result, hasLength(2));
      expect(result[0], hasLength(2));
      expect(result[1], hasLength(1));
    });
  });
}

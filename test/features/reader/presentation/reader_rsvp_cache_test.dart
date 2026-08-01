import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  tearDown(() => clearChapterWordsCache());

  group('chapter words cache', () {
    test('cache stores words per chapter index', () {
      putChapterWordsForTest(0, ['hello', 'world']);
      putChapterWordsForTest(1, ['foo', 'bar', 'baz']);

      final cache = chapterWordsCacheForTest;
      expect(cache[0], ['hello', 'world']);
      expect(cache[1], ['foo', 'bar', 'baz']);
      expect(cache[2], isNull);
    });

    test('evicting a chapter removes its words from cache', () {
      putChapterWordsForTest(0, ['a']);
      putChapterWordsForTest(1, ['b']);
      putChapterWordsForTest(2, ['c']);

      evictChapterWords([1]);

      final cache = chapterWordsCacheForTest;
      expect(cache[0], ['a']);
      expect(cache[1], isNull);
      expect(cache[2], ['c']);
    });

    test('evicting multiple chapters removes all their entries', () {
      putChapterWordsForTest(0, ['a']);
      putChapterWordsForTest(1, ['b']);
      putChapterWordsForTest(2, ['c']);
      putChapterWordsForTest(3, ['d']);

      evictChapterWords([0, 3]);

      final cache = chapterWordsCacheForTest;
      expect(cache[0], isNull);
      expect(cache[1], ['b']);
      expect(cache[2], ['c']);
      expect(cache[3], isNull);
    });

    test('evicting non-existent chapter is a no-op', () {
      putChapterWordsForTest(0, ['a']);

      evictChapterWords([99]);

      expect(chapterWordsCacheForTest[0], ['a']);
    });

    test('evicting empty list is a no-op', () {
      putChapterWordsForTest(0, ['a']);

      evictChapterWords([]);

      expect(chapterWordsCacheForTest[0], ['a']);
    });

    test('clearChapterWordsCache removes all entries', () {
      putChapterWordsForTest(0, ['a']);
      putChapterWordsForTest(5, ['b']);

      clearChapterWordsCache();

      expect(chapterWordsCacheForTest, isEmpty);
    });

    test('disposeChapterWordsCache removes all entries', () {
      putChapterWordsForTest(0, ['a']);
      putChapterWordsForTest(1, ['b']);

      disposeChapterWordsCache();

      expect(chapterWordsCacheForTest, isEmpty);
    });

    test('evicted entries can be re-populated', () {
      putChapterWordsForTest(0, ['old']);
      evictChapterWords([0]);
      expect(chapterWordsCacheForTest[0], isNull);

      putChapterWordsForTest(0, ['new']);
      expect(chapterWordsCacheForTest[0], ['new']);
    });

    test('cache supports incremental updates — add new chapter without '
        'affecting existing ones', () {
      putChapterWordsForTest(0, ['chapter', 'zero']);

      putChapterWordsForTest(1, ['chapter', 'one']);

      final cache = chapterWordsCacheForTest;
      expect(cache[0], ['chapter', 'zero']);
      expect(cache[1], ['chapter', 'one']);
      expect(cache.length, 2);
    });

    test('overwriting a chapter replaces its words', () {
      putChapterWordsForTest(0, ['old', 'words']);
      putChapterWordsForTest(0, ['new', 'words']);

      expect(chapterWordsCacheForTest[0], ['new', 'words']);
    });
  });
}

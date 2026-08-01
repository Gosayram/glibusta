import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  tearDown(() => clearRenderItemsCache());

  group('chapter render items cache', () {
    test('caches render items per chapter index', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'hello'),
          ReaderBlock(index: 1, text: 'world'),
        ],
      );

      putRenderItemsForTest(0, chapter, null);
      expect(renderItemsCountForTest(0), 2);
    });

    test('returns cached instance on subsequent calls with same content', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'hello'),
        ],
      );

      putRenderItemsForTest(0, chapter, null);
      final hash1 = renderItemsHashForTest(0);
      putRenderItemsForTest(0, chapter, null);
      final hash2 = renderItemsHashForTest(0);

      expect(hash1, hash2);
      expect(renderItemsForTest(0), isNotNull);
    });

    test('different chapters get separate cache entries', () {
      const ch0 = ReaderChapter(
        index: 0,
        title: 'Ch0',
        blocks: [ReaderBlock(index: 0, text: 'a')],
      );
      const ch1 = ReaderChapter(
        index: 1,
        title: 'Ch1',
        blocks: [ReaderBlock(index: 0, text: 'b')],
      );

      putRenderItemsForTest(0, ch0, null);
      putRenderItemsForTest(1, ch1, null);

      expect(renderItemsCountForTest(0), 1);
      expect(renderItemsCountForTest(1), 1);
    });

    test('evictChapterRenderItems removes specified entries', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [ReaderBlock(index: 0, text: 'x')],
      );

      putRenderItemsForTest(0, chapter, null);
      expect(renderItemsForTest(0), isNotNull);

      evictChapterRenderItems([0]);
      expect(renderItemsForTest(0), isNull);
    });

    test('evictChapterRenderItems does not remove other entries', () {
      const ch0 = ReaderChapter(
        index: 0,
        title: 'Ch0',
        blocks: [ReaderBlock(index: 0, text: 'a')],
      );
      const ch1 = ReaderChapter(
        index: 1,
        title: 'Ch1',
        blocks: [ReaderBlock(index: 0, text: 'b')],
      );

      putRenderItemsForTest(0, ch0, null);
      putRenderItemsForTest(1, ch1, null);

      evictChapterRenderItems([0]);
      expect(renderItemsForTest(0), isNull);
      expect(renderItemsForTest(1), isNotNull);
    });

    test('clearRenderItemsCache removes all entries', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [ReaderBlock(index: 0, text: 'x')],
      );

      putRenderItemsForTest(0, chapter, null);
      clearRenderItemsCache();
      expect(renderItemsForTest(0), isNull);
    });

    test('cache is invalidated when chapter content changes', () {
      const ch0v1 = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [ReaderBlock(index: 0, text: 'old')],
      );
      const ch0v2 = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'new'),
          ReaderBlock(index: 1, text: 'extra'),
        ],
      );

      putRenderItemsForTest(0, ch0v1, null);
      expect(renderItemsCountForTest(0), 1);

      putRenderItemsForTest(0, ch0v2, null);
      expect(renderItemsCountForTest(0), 2);
    });

    test('cache is invalidated when block transformers count changes', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [ReaderBlock(index: 0, text: 'x')],
      );

      putRenderItemsForTest(0, chapter, null);
      final hash1 = renderItemsHashForTest(0);

      putRenderItemsForTest(0, chapter, [_noopTransformer]);
      final hash2 = renderItemsHashForTest(0);

      expect(hash1, isNot(hash2));
    });

    test('cache persists across simulated rebuilds', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'a'),
          ReaderBlock(index: 1, text: 'b'),
        ],
      );

      putRenderItemsForTest(0, chapter, null);
      final items1 = renderItemsForTest(0);

      putRenderItemsForTest(0, chapter, null);
      final items2 = renderItemsForTest(0);

      putRenderItemsForTest(0, chapter, null);
      final items3 = renderItemsForTest(0);

      expect(identical(items1, items2), isTrue);
      expect(identical(items1, items3), isTrue);
    });

    test('eviction on non-existent index is a no-op', () {
      evictChapterRenderItems([99]);
      expect(renderItemsForTest(99), isNull);
    });

    test('eviction on empty list is a no-op', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [ReaderBlock(index: 0, text: 'x')],
      );

      putRenderItemsForTest(0, chapter, null);
      evictChapterRenderItems([]);
      expect(renderItemsForTest(0), isNotNull);
    });
  });
}

ReaderBlock? _noopTransformer(ReaderBlock block) => block;

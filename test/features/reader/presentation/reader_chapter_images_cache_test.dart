import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  tearDown(() => clearChapterImagesCache());

  group('chapter images cache', () {
    test('extracts image URLs from chapter blocks', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'hello'),
          ReaderBlock(
            index: 1,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/img1.png',
          ),
          ReaderBlock(index: 2, text: 'world'),
          ReaderBlock(
            index: 3,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/img2.png',
          ),
        ],
      );

      final result = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(result, ['https://example.com/img1.png', 'https://example.com/img2.png']);
    });

    test('skips image blocks without URL', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(
            index: 0,
            text: '',
            type: BlockType.image,
          ),
          ReaderBlock(
            index: 1,
            text: '',
            type: BlockType.image,
            imageUrl: '',
          ),
          ReaderBlock(
            index: 2,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/valid.png',
          ),
        ],
      );

      final result = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(result, ['https://example.com/valid.png']);
    });

    test('returns empty list for chapter with no images', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'hello'),
          ReaderBlock(index: 1, text: 'world'),
        ],
      );

      final result = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(result, isEmpty);
    });

    test('cached list is identical instance on repeated access', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(
            index: 0,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/img.png',
          ),
        ],
      );

      final first = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      final second = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));

      expect(identical(first, second), isTrue);
    });

    test('different chapters get separate cache entries', () {
      const ch0 = ReaderChapter(
        index: 0,
        title: 'Ch0',
        blocks: [
          ReaderBlock(
            index: 0,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/ch0.png',
          ),
        ],
      );
      const ch1 = ReaderChapter(
        index: 1,
        title: 'Ch1',
        blocks: [
          ReaderBlock(
            index: 0,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/ch1.png',
          ),
        ],
      );

      putIfAbsentChapterImages(0, () => _extractChapterImages(ch0));
      putIfAbsentChapterImages(1, () => _extractChapterImages(ch1));

      expect(chapterImagesForTest(0), ['https://example.com/ch0.png']);
      expect(chapterImagesForTest(1), ['https://example.com/ch1.png']);
    });

    test('clearChapterImagesCache invalidates cache', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(
            index: 0,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/img.png',
          ),
        ],
      );

      final first = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      clearChapterImagesCache();
      expect(chapterImagesForTest(0), isNull);

      final second = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(first, second);
      expect(identical(first, second), isFalse);
    });

    test('cache persists across simulated rebuilds', () {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Test',
        blocks: [
          ReaderBlock(index: 0, text: 'text'),
          ReaderBlock(
            index: 1,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/a.png',
          ),
          ReaderBlock(
            index: 2,
            text: '',
            type: BlockType.image,
            imageUrl: 'https://example.com/b.png',
          ),
        ],
      );

      final firstResult = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(firstResult, ['https://example.com/a.png', 'https://example.com/b.png']);

      final secondResult = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(identical(firstResult, secondResult), isTrue);

      final thirdResult = putIfAbsentChapterImages(0, () => _extractChapterImages(chapter));
      expect(identical(firstResult, thirdResult), isTrue);
    });
  });
}

List<String> _extractChapterImages(ReaderChapter chapter) {
  return chapter.blocks
      .where((b) => b.type == BlockType.image && b.imageUrl != null && b.imageUrl!.isNotEmpty)
      .map((b) => b.imageUrl!)
      .toList();
}

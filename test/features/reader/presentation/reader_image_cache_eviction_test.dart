import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  tearDown(() => clearChapterImagesCache());

  group('chapter images cache eviction', () {
    test('evicting a chapter removes its image cache entry', () {
      putIfAbsentChapterImages(0, () => ['img0.png']);
      putIfAbsentChapterImages(1, () => ['img1.png']);
      putIfAbsentChapterImages(2, () => ['img2.png']);

      evictChapterImages([1]);

      expect(chapterImagesForTest(0), ['img0.png']);
      expect(chapterImagesForTest(1), isNull);
      expect(chapterImagesForTest(2), ['img2.png']);
    });

    test('evicting multiple chapters removes all their entries', () {
      putIfAbsentChapterImages(0, () => ['img0.png']);
      putIfAbsentChapterImages(1, () => ['img1.png']);
      putIfAbsentChapterImages(2, () => ['img2.png']);
      putIfAbsentChapterImages(3, () => ['img3.png']);

      evictChapterImages([0, 3]);

      expect(chapterImagesForTest(0), isNull);
      expect(chapterImagesForTest(1), ['img1.png']);
      expect(chapterImagesForTest(2), ['img2.png']);
      expect(chapterImagesForTest(3), isNull);
    });

    test('evicting non-existent chapter is a no-op', () {
      putIfAbsentChapterImages(0, () => ['img0.png']);

      evictChapterImages([99]);

      expect(chapterImagesForTest(0), ['img0.png']);
    });

    test('evicting empty list is a no-op', () {
      putIfAbsentChapterImages(0, () => ['img0.png']);

      evictChapterImages([]);

      expect(chapterImagesForTest(0), ['img0.png']);
    });

    test('cache does not grow beyond loaded chapters after eviction', () {
      for (var i = 0; i < 10; i++) {
        putIfAbsentChapterImages(i, () => ['img$i.png']);
      }

      evictChapterImages([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

      for (var i = 0; i < 10; i++) {
        expect(chapterImagesForTest(i), isNull);
      }
    });

    test('clearChapterImagesCache removes all entries', () {
      putIfAbsentChapterImages(0, () => ['img0.png']);
      putIfAbsentChapterImages(5, () => ['img5.png']);

      clearChapterImagesCache();

      expect(chapterImagesForTest(0), isNull);
      expect(chapterImagesForTest(5), isNull);
    });

    test('evicted entries can be re-populated', () {
      putIfAbsentChapterImages(0, () => ['old.png']);
      evictChapterImages([0]);
      expect(chapterImagesForTest(0), isNull);

      final result = putIfAbsentChapterImages(0, () => ['new.png']);
      expect(result, ['new.png']);
      expect(chapterImagesForTest(0), ['new.png']);
    });
  });
}

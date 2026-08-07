import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_checkBookFinished gate logic', () {
    // Test the gate condition: onLastChapter && scrollProgress >= 0.99
    bool shouldFireFinishedDialog({
      required int chapterCount,
      required int currentChapterIndex,
      required double scrollProgress,
    }) {
      final onLastChapter = chapterCount <= 1 || currentChapterIndex >= chapterCount - 1;
      return onLastChapter && scrollProgress >= 0.99;
    }

    test('does not fire mid-book in multi-chapter continuous', () {
      // Chapter 3 of 20, scrolled to bottom of loaded window
      expect(
        shouldFireFinishedDialog(
          chapterCount: 20,
          currentChapterIndex: 3,
          scrollProgress: 0.99,
        ),
        isFalse,
      );
    });

    test('fires on last chapter of multi-chapter book', () {
      expect(
        shouldFireFinishedDialog(
          chapterCount: 20,
          currentChapterIndex: 19,
          scrollProgress: 0.995,
        ),
        isTrue,
      );
    });

    test('fires for single-chapter book at end', () {
      expect(
        shouldFireFinishedDialog(
          chapterCount: 1,
          currentChapterIndex: 0,
          scrollProgress: 0.99,
        ),
        isTrue,
      );
    });

    test('does not fire when progress < 0.99 even on last chapter', () {
      expect(
        shouldFireFinishedDialog(
          chapterCount: 5,
          currentChapterIndex: 4,
          scrollProgress: 0.50,
        ),
        isFalse,
      );
    });

    test('does not fire at chapter 0 of multi-chapter', () {
      expect(
        shouldFireFinishedDialog(
          chapterCount: 10,
          currentChapterIndex: 0,
          scrollProgress: 1.0,
        ),
        isFalse,
      );
    });
  });
}

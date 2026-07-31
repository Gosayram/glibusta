// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';

Map<int, ReaderChapter> _makeChapters(int count) {
  return {
    for (var i = 0; i < count; i++)
      i: ReaderChapter(
        index: i,
        title: 'Chapter $i',
        blocks: List.generate(10, (j) => ReaderBlock(index: j, text: 'block $j')),
      ),
  };
}

void main() {
  group('merged scroll state — copyWith with all three fields', () {
    test('single copyWith sets scrollProgress, currentPosition, and estimatedMinutesLeft', () {
      var state = ReaderState(loadingStage: null, scrollProgress: 0, estimatedMinutesLeft: 0);

      const progress = 0.45;
      final position = ReaderPosition(
        bookId: 'b',
        chapterIndex: 4,
        paragraphIndex: 3,
        progressPercent: progress,
        updatedAt: DateTime(2026),
      );

      state = state.copyWith(
        scrollProgress: progress,
        currentPosition: position,
        estimatedMinutesLeft: 12,
      );

      expect(state.scrollProgress, progress);
      expect(state.currentPosition.chapterIndex, 4);
      expect(state.currentPosition.paragraphIndex, 3);
      expect(state.currentPosition.progressPercent, progress);
      expect(state.estimatedMinutesLeft, 12);
    });

    test('copyWith with only scrollProgress preserves position unchanged', () {
      final initial = ReaderPosition(
        bookId: 'b',
        chapterIndex: 2,
        paragraphIndex: 1,
        progressPercent: 0.2,
        updatedAt: DateTime(2026),
      );
      final state = ReaderState(
        loadingStage: null,
        currentPosition: initial,
        scrollProgress: 0.2,
      );
      final updated = state.copyWith(scrollProgress: 0.6);
      expect(updated.scrollProgress, 0.6);
      expect(updated.currentPosition, same(initial));
    });
  });

  group('resolveChapterAtViewportTop', () {
    test('returns correct chapter for various offsets', () {
      final positions = [0.0, 500.0, 1200.0, 2000.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        0,
      );
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 700,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        1,
      );
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 1500,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        2,
      );
    });

    test('returns 0 for empty positions', () {
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 100,
          chapterPositions: const [],
          totalChapters: 5,
        ),
        0,
      );
    });
  });

  group('estimatePositionFromProgress', () {
    test('progress 0 maps to chapter 0', () {
      final chapters = _makeChapters(10);
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: 10,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 0);
    });

    test('progress 1.0 maps to last chapter', () {
      final chapters = _makeChapters(10);
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.0,
        chapterCount: 10,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 9);
    });

    test('progress 0.5 maps to middle chapter', () {
      final chapters = _makeChapters(20);
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: 20,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, closeTo(10, 3));
    });

    test('chapter index never exceeds total - 1', () {
      final chapters = _makeChapters(5);
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final result = ReaderContentHelper.estimatePositionFromProgress(
          progress: p,
          chapterCount: 5,
          loadedChapters: chapters,
        );
        expect(result.chapterIndex, lessThan(5));
        expect(result.chapterIndex, greaterThanOrEqualTo(0));
      }
    });
  });
}

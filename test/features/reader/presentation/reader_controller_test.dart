import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';

void main() {
  group('ReaderState.estimatedChapterMinutesLeft', () {
    test('defaults to 0', () {
      final state = ReaderState();
      expect(state.estimatedChapterMinutesLeft, 0);
    });

    test('copyWith preserves value when not specified', () {
      final original = ReaderState(estimatedChapterMinutesLeft: 15);
      final copied = original.copyWith();
      expect(copied.estimatedChapterMinutesLeft, 15);
    });

    test('copyWith overrides value when specified', () {
      final original = ReaderState(estimatedChapterMinutesLeft: 15);
      final copied = original.copyWith(estimatedChapterMinutesLeft: 25);
      expect(copied.estimatedChapterMinutesLeft, 25);
    });
  });

  group('ReaderController.resolveChapterAtViewportTop', () {
    test('returns 0 when positions list is empty', () {
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: const [],
          totalChapters: 5,
        ),
        0,
      );
    });

    test('returns 0 when totalChapters is 0', () {
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: const [0, 100, 200],
          totalChapters: 0,
        ),
        0,
      );
    });

    test('returns 0 for single chapter at offset 0', () {
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: const [0],
          totalChapters: 1,
        ),
        0,
      );
    });

    test('resolves chapter 0 when scroll is at top', () {
      final positions = [0.0, 100.0, 250.0, 400.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        0,
      );
    });

    test('resolves chapter in the middle', () {
      final positions = [0.0, 100.0, 250.0, 400.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 150,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        1,
      );
    });

    test('resolves chapter at exact boundary', () {
      final positions = [0.0, 100.0, 250.0, 400.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 100,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        1,
      );
    });

    test('resolves last chapter at max offset', () {
      final positions = [0.0, 100.0, 250.0, 400.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 500,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        3,
      );
    });

    test('resolves last chapter at exact last position', () {
      final positions = [0.0, 100.0, 250.0, 400.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 400,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        3,
      );
    });

    test('clamps to totalChapters - 1 when offset exceeds positions', () {
      final positions = [0.0, 100.0, 200.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 1000,
          chapterPositions: positions,
          totalChapters: 2,
        ),
        1,
      );
    });

    test('handles two chapters with viewport halfway between them', () {
      final positions = [0.0, 500.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 250,
          chapterPositions: positions,
          totalChapters: 2,
        ),
        0,
      );
    });

    test('handles two chapters with viewport past midpoint', () {
      final positions = [0.0, 500.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 500,
          chapterPositions: positions,
          totalChapters: 2,
        ),
        1,
      );
    });
  });
}

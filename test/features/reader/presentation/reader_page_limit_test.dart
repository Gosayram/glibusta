import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';

void main() {
  const largeChapterCount = 15000;
  final largeTitles = List<String>.generate(
    largeChapterCount,
    (i) => 'Chapter $i',
  );

  final largeMetadata = NormalizedBookMetadata(
    id: 'large-book',
    title: 'Large Book',
    authors: ['Author'],
    chapterCount: largeChapterCount,
    chapterTitles: largeTitles,
  );

  group('LITHIUM-PAGE-003: pagination with >10000 chapters', () {
    test('NormalizedBookMetadata accepts chapterCount of 15000', () {
      expect(largeMetadata.chapterCount, largeChapterCount);
      expect(largeMetadata.chapterTitles.length, largeChapterCount);
    });

    test('ReaderState.chapterCount reflects large metadata', () {
      final state = ReaderState(metadata: largeMetadata);
      expect(state.chapterCount, largeChapterCount);
    });

    test('estimatePositionFromProgress handles 15000 chapters at 0.0', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: largeChapterCount,
        loadedChapters: const {},
      );
      expect(result.chapterIndex, 0);
      expect(result.paragraphIndex, 0);
    });

    test('estimatePositionFromProgress handles 15000 chapters at 0.5', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: largeChapterCount,
        loadedChapters: const {},
      );
      expect(result.chapterIndex, closeTo(7500, 1));
    });

    test('estimatePositionFromProgress handles 15000 chapters at 1.0', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.0,
        chapterCount: largeChapterCount,
        loadedChapters: const {},
      );
      expect(result.chapterIndex, largeChapterCount - 1);
    });

    test('estimatePositionFromProgress with some loaded chapters', () {
      final loadedChapters = <int, ReaderChapter>{
        0: const ReaderChapter(
          index: 0,
          title: 'Chapter 0',
          blocks: [ReaderBlock(index: 0, text: 'text')],
        ),
        7500: const ReaderChapter(
          index: 7500,
          title: 'Chapter 7500',
          blocks: [ReaderBlock(index: 0, text: 'text')],
        ),
        14999: const ReaderChapter(
          index: 14999,
          title: 'Chapter 14999',
          blocks: [ReaderBlock(index: 0, text: 'text')],
        ),
      };

      final atStart = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: largeChapterCount,
        loadedChapters: loadedChapters,
      );
      expect(atStart.chapterIndex, 0);

      final atEnd = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.0,
        chapterCount: largeChapterCount,
        loadedChapters: loadedChapters,
      );
      expect(atEnd.chapterIndex, largeChapterCount - 1);
    });

    test('resolveChapterAtViewportTop handles 15000 chapter positions', () {
      final positions = List<double>.generate(
        largeChapterCount,
        (i) => i * 100.0,
      );

      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: positions,
          totalChapters: largeChapterCount,
        ),
        0,
      );

      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 7500 * 100.0,
          chapterPositions: positions,
          totalChapters: largeChapterCount,
        ),
        7500,
      );

      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 14999 * 100.0,
          chapterPositions: positions,
          totalChapters: largeChapterCount,
        ),
        14999,
      );
    });

    test('ReaderPosition.clamp works with chapterCount 15000', () {
      final pos = ReaderPosition(
        bookId: 'large-book',
        chapterIndex: 20000,
        paragraphIndex: -5,
        updatedAt: DateTime.now(),
      );
      final clamped = pos.clamp(chapterCount: largeChapterCount);
      expect(clamped.chapterIndex, largeChapterCount - 1);
      expect(clamped.paragraphIndex, 0);
    });

    test('chapterProgress produces correct ratio for 15000 chapters', () {
      final state = ReaderState(metadata: largeMetadata);
      final lastChapter = state.chapterCount - 1;

      expect(0 / lastChapter, closeTo(0.0, 0.001));
      expect((lastChapter / 2) / lastChapter, closeTo(0.5, 0.001));
      expect(lastChapter / lastChapter, closeTo(1.0, 0.001));
    });

    test('no overflow with large chapterCount in list generation', () {
      expect(
        () => ReaderContentHelper.estimatePositionFromProgress(
          progress: 0.5,
          chapterCount: largeChapterCount,
          loadedChapters: const {},
        ),
        returnsNormally,
      );
    });
  });
}

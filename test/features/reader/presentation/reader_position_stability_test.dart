import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';

Map<int, ReaderChapter> _makeChapters(
  int count, {
  int Function(int index)? blocksPerChapter,
}) {
  final blocks = blocksPerChapter ?? (i) => (i % 10) + 5;
  return {
    for (var i = 0; i < count; i++)
      i: ReaderChapter(
        index: i,
        title: 'Chapter $i',
        blocks: List.generate(
          blocks(i),
          (j) => ReaderBlock(index: j, text: 'block $j'),
        ),
      ),
  };
}

void main() {
  const chapterCount = 100;

  group('estimatePositionFromProgress — basic mapping', () {
    final chapters = _makeChapters(chapterCount);

    test('progress 0.0 maps to chapter 0', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: chapterCount,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 0);
    });

    test('progress 1.0 maps to last chapter', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.0,
        chapterCount: chapterCount,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, chapterCount - 1);
    });

    test('progress 0.5 maps to around chapter 50', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: chapterCount,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, closeTo(50, 5));
    });

    test('progress 0.25 maps to around chapter 25', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.25,
        chapterCount: chapterCount,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, closeTo(25, 5));
    });

    test('progress 0.75 maps to around chapter 75', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.75,
        chapterCount: chapterCount,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, closeTo(75, 5));
    });
  });

  group('estimatePositionFromProgress — bounds safety', () {
    final chapters = _makeChapters(chapterCount);

    test('chapter index is never negative', () {
      for (final progress in [0.0, 0.001, 0.01, 0.1]) {
        final result = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: chapters,
        );
        expect(
          result.chapterIndex,
          greaterThanOrEqualTo(0),
          reason: 'progress=$progress',
        );
      }
    });

    test('chapter index is never >= chapterCount', () {
      for (final progress in [0.9, 0.99, 0.999, 1.0]) {
        final result = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: chapters,
        );
        expect(
          result.chapterIndex,
          lessThan(chapterCount),
          reason: 'progress=$progress',
        );
      }
    });

    test('chapterCount 0 returns chapter 0', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: 0,
        loadedChapters: const {},
      );
      expect(result.chapterIndex, 0);
    });

    test('chapterCount 1 always returns chapter 0', () {
      final singleChapter = _makeChapters(1);
      for (final p in [0.0, 0.5, 1.0]) {
        final result = ReaderContentHelper.estimatePositionFromProgress(
          progress: p,
          chapterCount: 1,
          loadedChapters: singleChapter,
        );
        expect(result.chapterIndex, 0, reason: 'progress=$p');
      }
    });
  });

  group('estimatePositionFromProgress — font change stability', () {
    test('same semantic position maps to same chapter before and after font change', () {
      final originalChapters = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => (i % 10) + 5,
      );
      final largerChapters = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => ((i % 10) + 5) * 2,
      );
      final smallerChapters = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => ((i % 10) + 5) ~/ 2 + 1,
      );

      for (final progress in [0.1, 0.25, 0.5, 0.75, 0.9]) {
        final before = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: originalChapters,
        );
        final afterLarger = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: largerChapters,
        );
        final afterSmaller = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: smallerChapters,
        );
        expect(
          before.chapterIndex,
          afterLarger.chapterIndex,
          reason: 'progress=$progress — larger font',
        );
        expect(
          before.chapterIndex,
          afterSmaller.chapterIndex,
          reason: 'progress=$progress — smaller font',
        );
      }
    });

    test('progress drift after font change is within tolerance', () {
      final originalChapters = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => (i % 10) + 5,
      );
      final postFontChangeChapters = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => ((i % 10) + 5) * 3,
      );

      for (final progress in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
        final before = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: originalChapters,
        );
        final after = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: postFontChangeChapters,
        );
        final chapterDiff = (before.chapterIndex - after.chapterIndex).abs();
        expect(
          chapterDiff,
          lessThanOrEqualTo(2),
          reason: 'progress=$progress chapter drift=$chapterDiff',
        );
      }
    });

    test('uniform chapters — font change has zero drift', () {
      final uniformA = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => i + 1,
      );
      final uniformB = _makeChapters(
        chapterCount,
        blocksPerChapter: (i) => (i + 1) * 2,
      );

      for (final progress in [0.0, 0.3, 0.5, 0.7, 0.99]) {
        final before = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: uniformA,
        );
        final after = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: chapterCount,
          loadedChapters: uniformB,
        );
        expect(
          (before.chapterIndex - after.chapterIndex).abs(),
          lessThanOrEqualTo(2),
          reason: 'progress=$progress',
        );
      }
    });
  });

  group('estimatePositionFromProgress — unloaded chapters', () {
    test('uses average weight for missing chapters', () {
      final partialChapters = _makeChapters(
        chapterCount,
        blocksPerChapter: (_) => 10,
      );
      final onlyFirst = {0: partialChapters[0]!};

      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: chapterCount,
        loadedChapters: onlyFirst,
      );
      expect(result.chapterIndex, greaterThanOrEqualTo(0));
      expect(result.chapterIndex, lessThan(chapterCount));
    });

    test('empty loaded chapters defaults to uniform weight', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: chapterCount,
        loadedChapters: const {},
      );
      expect(result.chapterIndex, closeTo(50, 1));
    });
  });

  group('estimatePositionFromProgress — paragraph index', () {
    test('progress within a chapter maps to reasonable paragraph index', () {
      final chapters = _makeChapters(
        2,
        blocksPerChapter: (_) => 10,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.75,
        chapterCount: 2,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 1);
      expect(result.paragraphIndex, greaterThanOrEqualTo(0));
      expect(result.paragraphIndex, lessThanOrEqualTo(9));
    });

    test('progress at chapter boundary maps to paragraph 0', () {
      final chapters = _makeChapters(
        10,
        blocksPerChapter: (_) => 5,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: 10,
        loadedChapters: chapters,
      );
      expect(result.paragraphIndex, 0);
    });
  });
}

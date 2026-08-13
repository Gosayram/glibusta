import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';

Map<int, ReaderChapter> _makeChapters(
  int count, {
  int Function(int index)? blocksPerChapter,
}) {
  final blocksFn = blocksPerChapter ?? (i) => (i % 10) + 5;
  return {
    for (var i = 0; i < count; i++)
      i: ReaderChapter(
        index: i,
        title: 'Chapter $i',
        blocks: List.generate(
          blocksFn(i),
          (j) => ReaderBlock(index: j, text: 'block $j'),
        ),
      ),
  };
}

({int chapterIndex, int paragraphIndex}) _originalEstimate({
  required double progress,
  required int chapterCount,
  required Map<int, ReaderChapter> loadedChapters,
}) {
  if (chapterCount <= 0) return (chapterIndex: 0, paragraphIndex: 0);

  var averageBlocks = 1.0;
  if (loadedChapters.isNotEmpty) {
    averageBlocks =
        loadedChapters.values
            .map(
              (chapter) => chapter.blocks.isEmpty ? 1.0 : chapter.blocks.length.toDouble(),
            )
            .fold<double>(0, (sum, count) => sum + count) /
        loadedChapters.length;
  }

  final weights = List<double>.generate(chapterCount, (index) {
    final blockCount = loadedChapters[index]?.blocks.length;
    return blockCount == null || blockCount <= 0 ? averageBlocks : blockCount.toDouble();
  });
  final totalWeight = weights.fold<double>(0, (sum, weight) => sum + weight);
  final targetWeight = progress.clamp(0.0, 1.0) * totalWeight;

  var precedingWeight = 0.0;
  for (var index = 0; index < weights.length; index++) {
    final chapterWeight = weights[index];
    final cumulativeWeight = precedingWeight + chapterWeight;
    if (targetWeight <= cumulativeWeight || index == weights.length - 1) {
      final blockCount = loadedChapters[index]?.blocks.length ?? 0;
      final lastParagraph = blockCount > 0 ? blockCount - 1 : 0;
      final localProgress = ((targetWeight - precedingWeight) / chapterWeight).clamp(0.0, 1.0);
      return (
        chapterIndex: index,
        paragraphIndex: (localProgress * lastParagraph).round(),
      );
    }
    precedingWeight = cumulativeWeight;
  }

  return (chapterIndex: chapterCount - 1, paragraphIndex: 0);
}

void main() {
  group('estimatePositionFromProgress — matches original', () {
    test('fully loaded book at multiple progress values', () {
      final chapters = _makeChapters(100);
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final expected = _originalEstimate(
          progress: p,
          chapterCount: 100,
          loadedChapters: chapters,
        );
        final actual = ReaderContentHelper.estimatePositionFromProgress(
          progress: p,
          chapterCount: 100,
          loadedChapters: chapters,
        );
        expect(actual, expected, reason: 'progress=$p');
      }
    });

    test('partially loaded book', () {
      final allChapters = _makeChapters(200);
      final partial = Map<int, ReaderChapter>.fromEntries(
        allChapters.entries.where((e) => e.key >= 50 && e.key <= 70),
      );
      for (final p in [0.0, 0.3, 0.5, 0.8, 1.0]) {
        final expected = _originalEstimate(
          progress: p,
          chapterCount: 200,
          loadedChapters: partial,
        );
        final actual = ReaderContentHelper.estimatePositionFromProgress(
          progress: p,
          chapterCount: 200,
          loadedChapters: partial,
        );
        expect(actual, expected, reason: 'progress=$p');
      }
    });

    test('empty loaded chapters', () {
      for (final p in [0.0, 0.5, 1.0]) {
        final expected = _originalEstimate(
          progress: p,
          chapterCount: 50,
          loadedChapters: const {},
        );
        final actual = ReaderContentHelper.estimatePositionFromProgress(
          progress: p,
          chapterCount: 50,
          loadedChapters: const {},
        );
        expect(actual, expected, reason: 'progress=$p');
      }
    });
  });

  group('estimatePositionFromProgress — edge cases', () {
    test('zero chapters returns (0, 0)', () {
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.5,
        chapterCount: 0,
        loadedChapters: const {},
      );
      expect(result, (chapterIndex: 0, paragraphIndex: 0));
    });

    test('single chapter returns (0, paragraph)', () {
      final chapters = _makeChapters(1);
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: 1,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 0);

      final result100 = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.0,
        chapterCount: 1,
        loadedChapters: chapters,
      );
      expect(result100.chapterIndex, 0);
    });

    test('progress 0.0 maps to chapter 0', () {
      final chapters = _makeChapters(100);
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 0.0,
        chapterCount: 100,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 0);
    });

    test('progress 1.0 maps to last chapter', () {
      final chapters = _makeChapters(100);
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.0,
        chapterCount: 100,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 99);
    });

    test('clamps out-of-range progress', () {
      final chapters = _makeChapters(10);
      final under = ReaderContentHelper.estimatePositionFromProgress(
        progress: -0.5,
        chapterCount: 10,
        loadedChapters: chapters,
      );
      expect(under.chapterIndex, 0);

      final over = ReaderContentHelper.estimatePositionFromProgress(
        progress: 1.5,
        chapterCount: 10,
        loadedChapters: chapters,
      );
      expect(over.chapterIndex, 9);
    });
  });
}

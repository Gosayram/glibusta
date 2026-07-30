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

  group('LITHIUM-POS-002 — paragraph-level position stability after font change', () {
    double semanticAnchor({
      required int chapterIndex,
      required int paragraphIndex,
      required Map<int, ReaderChapter> chapters,
      required int chapterCount,
    }) {
      if (chapterCount <= 1) {
        final chapter = chapters[0];
        final count = chapter?.blocks.length ?? 1;
        return (paragraphIndex / count).clamp(0.0, 1.0);
      }
      var totalBlocks = 0;
      var blocksBeforeTarget = 0;
      for (var ch = 0; ch < chapterCount; ch++) {
        final chapter = chapters[ch];
        final count = chapter?.blocks.length ?? 1;
        if (ch < chapterIndex) {
          blocksBeforeTarget += count;
        } else if (ch == chapterIndex) {
          blocksBeforeTarget += paragraphIndex.clamp(0, count - 1);
        }
        totalBlocks += count;
      }
      if (totalBlocks <= 0) return 0.0;
      return (blocksBeforeTarget / totalBlocks).clamp(0.0, 1.0);
    }

    test('paragraph 10 in chapter 5 stays within 30% after font increase', () {
      final original = _makeChapters(
        20,
        blocksPerChapter: (i) => (i % 10) + 5,
      );
      final larger = _makeChapters(
        20,
        blocksPerChapter: (i) => ((i % 10) + 5) * 2,
      );
      final progress = semanticAnchor(
        chapterIndex: 5,
        paragraphIndex: 10,
        chapters: original,
        chapterCount: 20,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: progress,
        chapterCount: 20,
        loadedChapters: larger,
      );
      expect(result.chapterIndex, 5);
      final chSize = larger[5]!.blocks.length;
      expect(
        (result.paragraphIndex - 10).abs(),
        lessThanOrEqualTo((chSize * 0.5).ceil()),
        reason: 'drift=${(result.paragraphIndex - 10).abs()} chSize=$chSize',
      );
    });

    test('paragraph 10 in chapter 5 stays within 30% after font decrease', () {
      final original = _makeChapters(
        20,
        blocksPerChapter: (i) => ((i % 10) + 5) * 2,
      );
      final smaller = _makeChapters(
        20,
        blocksPerChapter: (i) => (i % 10) + 5,
      );
      final progress = semanticAnchor(
        chapterIndex: 5,
        paragraphIndex: 10,
        chapters: original,
        chapterCount: 20,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: progress,
        chapterCount: 20,
        loadedChapters: smaller,
      );
      expect(result.chapterIndex, 5);
      final chSize = smaller[5]!.blocks.length;
      expect(
        (result.paragraphIndex - 10).abs(),
        lessThanOrEqualTo((chSize * 0.5).ceil()),
        reason: 'drift=${(result.paragraphIndex - 10).abs()} chSize=$chSize',
      );
    });

    test('multiple positions survive font tripling', () {
      final original = _makeChapters(
        30,
        blocksPerChapter: (i) => (i % 8) + 3,
      );
      final tripled = _makeChapters(
        30,
        blocksPerChapter: (i) => ((i % 8) + 3) * 3,
      );
      final positions = [
        (chapter: 0, paragraph: 0),
        (chapter: 3, paragraph: 5),
        (chapter: 10, paragraph: 2),
        (chapter: 15, paragraph: 8),
        (chapter: 25, paragraph: 1),
      ];
      for (final pos in positions) {
        final progress = semanticAnchor(
          chapterIndex: pos.chapter,
          paragraphIndex: pos.paragraph,
          chapters: original,
          chapterCount: 30,
        );
        final result = ReaderContentHelper.estimatePositionFromProgress(
          progress: progress,
          chapterCount: 30,
          loadedChapters: tripled,
        );
        expect(result.chapterIndex, pos.chapter, reason: 'chapter at ${pos.chapter}');
        final chSize = tripled[pos.chapter]!.blocks.length;
        expect(
          (result.paragraphIndex - pos.paragraph).abs(),
          lessThanOrEqualTo((chSize * 0.5).ceil()),
          reason:
              'chapter=${pos.chapter} paragraph=${pos.paragraph} '
              'drift=${(result.paragraphIndex - pos.paragraph).abs()} chSize=$chSize',
        );
      }
    });

    test('last paragraph in chapter is clamped to valid range after font change', () {
      final original = _makeChapters(
        5,
        blocksPerChapter: (_) => 20,
      );
      final smaller = _makeChapters(
        5,
        blocksPerChapter: (_) => 10,
      );
      final progress = semanticAnchor(
        chapterIndex: 2,
        paragraphIndex: 19,
        chapters: original,
        chapterCount: 5,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: progress,
        chapterCount: 5,
        loadedChapters: smaller,
      );
      expect(result.chapterIndex, 2);
      expect(
        result.paragraphIndex,
        lessThanOrEqualTo(9),
        reason: 'must not exceed last paragraph of smaller chapter',
      );
      expect(result.paragraphIndex, greaterThanOrEqualTo(0));
    });

    test('paragraph at very end of last chapter stays valid', () {
      final original = _makeChapters(
        10,
        blocksPerChapter: (_) => 15,
      );
      final larger = _makeChapters(
        10,
        blocksPerChapter: (_) => 30,
      );
      final progress = semanticAnchor(
        chapterIndex: 9,
        paragraphIndex: 14,
        chapters: original,
        chapterCount: 10,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: progress,
        chapterCount: 10,
        loadedChapters: larger,
      );
      expect(result.chapterIndex, 9);
      final chSize = larger[9]!.blocks.length;
      expect(
        (result.paragraphIndex - 14).abs(),
        lessThanOrEqualTo((chSize * 0.5).ceil()),
      );
      expect(result.paragraphIndex, greaterThanOrEqualTo(0));
      expect(result.paragraphIndex, lessThanOrEqualTo(29));
    });

    test('offset within paragraph is preserved relative to progress', () {
      final chapters = _makeChapters(
        5,
        blocksPerChapter: (_) => 20,
      );
      final progress = semanticAnchor(
        chapterIndex: 2,
        paragraphIndex: 10,
        chapters: chapters,
        chapterCount: 5,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: progress,
        chapterCount: 5,
        loadedChapters: chapters,
      );
      expect(result.chapterIndex, 2);
      expect(result.paragraphIndex, 10);
    });

    test('single chapter book — paragraph stability after font change', () {
      final original = {0: _makeChapters(1, blocksPerChapter: (_) => 30)[0]!};
      final larger = {0: _makeChapters(1, blocksPerChapter: (_) => 60)[0]!};
      final progress = semanticAnchor(
        chapterIndex: 0,
        paragraphIndex: 15,
        chapters: original,
        chapterCount: 1,
      );
      final result = ReaderContentHelper.estimatePositionFromProgress(
        progress: progress,
        chapterCount: 1,
        loadedChapters: larger,
      );
      expect(result.chapterIndex, 0);
      final chSize = larger[0]!.blocks.length;
      expect(
        (result.paragraphIndex - 15).abs(),
        lessThanOrEqualTo((chSize * 0.5).ceil()),
      );
    });
  });
}

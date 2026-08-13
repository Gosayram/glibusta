import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/toc_hierarchy.dart';

ReaderChapter _chapter(int index, String title, List<ReaderBlock> blocks) {
  return ReaderChapter(index: index, title: title, blocks: blocks);
}

ReaderBlock _heading(int level, String text) {
  return ReaderBlock(index: 0, text: text, type: BlockType.heading, headingLevel: level);
}

ReaderBlock _paragraph(String text) {
  return ReaderBlock(index: 0, text: text);
}

void main() {
  group('buildTocFromHeadings', () {
    test('empty chapter titles use "Глава N" fallback', () {
      final chapters = {
        0: _chapter(0, '', [
          _heading(1, 'First heading'),
          _heading(2, 'Sub heading'),
        ]),
        1: _chapter(1, '', [
          _heading(1, 'Second heading'),
        ]),
      };
      final result = buildTocFromHeadings(['', ''], chapters);

      final chapterEntries = result.where((e) => e.depth == 0).toList();
      expect(chapterEntries.length, 2);
      expect(chapterEntries[0].title, 'Глава 1');
      expect(chapterEntries[1].title, 'Глава 2');
    });

    test('mixed empty and non-empty titles', () {
      final chapters = {
        0: _chapter(0, '   ', [
          _heading(1, 'H1'),
          _heading(2, 'H2'),
        ]),
        1: _chapter(1, 'Real Title', [
          _heading(1, 'H1'),
        ]),
      };
      final result = buildTocFromHeadings(['   ', 'Real Title'], chapters);

      final chapterEntries = result.where((e) => e.depth == 0).toList();
      expect(chapterEntries[0].title, 'Глава 1');
      expect(chapterEntries[1].title, 'Real Title');
    });

    test('chapter title out of bounds uses fallback', () {
      final chapters = {
        0: _chapter(0, 'A', [
          _heading(1, 'H1'),
          _heading(2, 'H2'),
        ]),
        5: _chapter(5, 'B', [
          _heading(1, 'H1'),
        ]),
      };
      final result = buildTocFromHeadings(['A'], chapters);

      final chapterEntries = result.where((e) => e.depth == 0).toList();
      expect(chapterEntries[0].title, 'A');
      expect(chapterEntries[1].title, 'Глава 6');
    });

    test('long titles truncated to 80 chars', () {
      final longTitle = 'A' * 120;
      final chapters = {
        0: _chapter(0, 'Ch', [_heading(1, longTitle)]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => !e.isGroup && e.depth > 0).toList();
      expect(headings.length, 1);
      expect(headings[0].title.length, 80);
      expect(headings[0].title.endsWith('\u2026'), isTrue);
    });

    test('short titles not truncated', () {
      final chapters = {
        0: _chapter(0, 'Ch', [_heading(1, 'Short')]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => !e.isGroup && e.depth > 0).toList();
      expect(headings[0].title, 'Short');
    });

    test('exactly 80 char title not truncated', () {
      final title80 = 'B' * 80;
      final chapters = {
        0: _chapter(0, 'Ch', [_heading(1, title80)]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => !e.isGroup && e.depth > 0).toList();
      expect(headings[0].title.length, 80);
      expect(headings[0].title.endsWith('\u2026'), isFalse);
    });

    test('h1 + h2 hierarchy creates correct nesting', () {
      final chapters = {
        0: _chapter(0, 'Chapter 1', [
          _heading(1, 'Part One'),
          _heading(2, 'Section A'),
          _heading(2, 'Section B'),
          _heading(1, 'Part Two'),
        ]),
      };
      final result = buildTocFromHeadings(['Chapter 1'], chapters);

      expect(result.length, 5);
      expect(result[0].depth, 0);
      expect(result[0].title, 'Chapter 1');
      expect(result[1].title, 'Part One');
      expect(result[1].depth, 1);
      expect(result[2].title, 'Section A');
      expect(result[2].depth, 2);
      expect(result[3].title, 'Section B');
      expect(result[3].depth, 2);
      expect(result[4].title, 'Part Two');
      expect(result[4].depth, 1);
    });

    test('h3 sub-headings included under parent h2', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'Part'),
          _heading(2, 'Section'),
          _heading(3, 'Subsection'),
          _heading(3, 'Another Sub'),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      expect(result.length, 5);
      expect(result[0].depth, 0);
      expect(result[1].title, 'Part');
      expect(result[1].depth, 1);
      expect(result[2].title, 'Section');
      expect(result[2].depth, 2);
      expect(result[3].title, 'Subsection');
      expect(result[3].depth, 3);
      expect(result[4].title, 'Another Sub');
      expect(result[4].depth, 3);
    });

    test('h2/h3 only book normalizes depth', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(2, 'Chapter'),
          _heading(3, 'Sub'),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[0].depth, 1);
      expect(headings[1].depth, 2);
    });

    test('h4 headings included in hierarchy', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'Top'),
          _heading(2, 'Section'),
          _heading(3, 'Sub'),
          _heading(4, 'Detail'),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      expect(result.length, 5);
      expect(result[4].title, 'Detail');
      expect(result[4].depth, 4);
    });

    test('no headings falls back to buildTocHierarchy', () {
      final chapters = {
        0: _chapter(0, 'Ch 1', [_paragraph('text')]),
        1: _chapter(1, 'Ch 2', [_paragraph('text')]),
      };
      final result = buildTocFromHeadings(['Ch 1', 'Ch 2'], chapters);

      expect(result.length, 2);
      expect(result[0].title, 'Ch 1');
      expect(result[1].title, 'Ch 2');
    });

    test('empty loadedChapters falls back to buildTocHierarchy', () {
      final result = buildTocFromHeadings(['Ch 1', 'Ch 2'], {});

      expect(result.length, 2);
      expect(result[0].title, 'Ch 1');
      expect(result[1].title, 'Ch 2');
    });

    test('multiple chapters with headings', () {
      final chapters = {
        0: _chapter(0, 'Intro', [
          _heading(1, 'Welcome'),
          _heading(2, 'Details'),
        ]),
        1: _chapter(1, 'Body', [
          _heading(1, 'Chapter Start'),
          _heading(2, 'Details'),
        ]),
        2: _chapter(2, 'End', [
          _heading(1, 'Conclusion'),
          _heading(2, 'Final'),
        ]),
      };
      final result = buildTocFromHeadings(['Intro', 'Body', 'End'], chapters);

      final chapterEntries = result.where((e) => e.depth == 0).toList();
      expect(chapterEntries.length, 3);
      expect(chapterEntries[0].title, 'Intro');
      expect(chapterEntries[1].title, 'Body');
      expect(chapterEntries[2].title, 'End');

      final allHeadings = result.where((e) => e.depth > 0).toList();
      expect(allHeadings.length, 6);
      expect(allHeadings[0].groupId, 0);
      expect(allHeadings[2].groupId, 1);
      expect(allHeadings[4].groupId, 2);
    });

    test('empty heading text is skipped', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, ''),
          _heading(1, '   '),
          _heading(1, 'Real'),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings.length, 1);
      expect(headings[0].title, 'Real');
    });

    test('chapter group isGroup true when multiple headings', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'A'),
          _heading(1, 'B'),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final groupEntry = result.firstWhere((e) => e.depth == 0);
      expect(groupEntry.isGroup, isTrue);
    });

    test('chapter group isGroup false when single heading', () {
      final chapters = {
        0: _chapter(0, 'Ch', [_heading(1, 'Only')]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final groupEntry = result.firstWhere((e) => e.depth == 0);
      expect(groupEntry.isGroup, isFalse);
    });

    test('long chapter title truncated via fallback', () {
      final longTitle = 'C' * 100;
      final chapters = {
        0: _chapter(0, longTitle, [_heading(1, 'H')]),
      };
      final result = buildTocFromHeadings([longTitle], chapters);

      final groupEntry = result.firstWhere((e) => e.depth == 0);
      expect(groupEntry.title.length, 80);
      expect(groupEntry.title.endsWith('\u2026'), isTrue);
    });
  });
}

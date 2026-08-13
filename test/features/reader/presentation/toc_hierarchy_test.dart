import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/toc_hierarchy.dart';

ReaderChapter _chapter(int index, String title, List<ReaderBlock> blocks) {
  return ReaderChapter(index: index, title: title, blocks: blocks);
}

ReaderBlock _heading(int level, String text, {int blockIndex = 0}) {
  return ReaderBlock(index: blockIndex, text: text, type: BlockType.heading, headingLevel: level);
}

ReaderBlock _paragraph(String text, {int blockIndex = 0}) {
  return ReaderBlock(index: blockIndex, text: text);
}

void main() {
  group('TocEntry heading level', () {
    test('preserves depth for H1-H3 hierarchy', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'Part'),
          _paragraph('text', blockIndex: 1),
          _heading(2, 'Section', blockIndex: 2),
          _heading(3, 'Sub', blockIndex: 3),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[0].depth, 1);
      expect(headings[1].depth, 2);
      expect(headings[2].depth, 3);
    });

    test('preserves depth for H2-H6 hierarchy when no H1', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(2, 'Top'),
          _heading(3, 'Mid', blockIndex: 1),
          _heading(4, 'Low', blockIndex: 2),
          _heading(5, 'Detail', blockIndex: 3),
          _heading(6, 'Fine', blockIndex: 4),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[0].depth, 1);
      expect(headings[1].depth, 2);
      expect(headings[2].depth, 3);
      expect(headings[3].depth, 4);
      expect(headings[4].depth, 5);
    });
  });

  group('TocEntry blockIndex', () {
    test('heading entry stores correct blockIndex', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _paragraph('intro'),
          _paragraph('more', blockIndex: 1),
          _heading(1, 'First Heading', blockIndex: 2),
          _paragraph('body', blockIndex: 3),
          _heading(2, 'Second Heading', blockIndex: 4),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[0].blockIndex, 2);
      expect(headings[1].blockIndex, 4);
    });

    test('chapter entry has blockIndex 0', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'H', blockIndex: 3),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final chapterEntry = result.firstWhere((e) => e.depth == 0);
      expect(chapterEntry.blockIndex, 0);
    });

    test('multiple chapters track blockIndex independently', () {
      final chapters = {
        0: _chapter(0, 'A', [
          _paragraph('p0'),
          _paragraph('p1', blockIndex: 1),
          _heading(1, 'HA', blockIndex: 2),
        ]),
        1: _chapter(1, 'B', [
          _heading(1, 'HB'),
          _paragraph('p1', blockIndex: 1),
          _heading(2, 'HB2', blockIndex: 2),
        ]),
      };
      final result = buildTocFromHeadings(['A', 'B'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[0].blockIndex, 2);
      expect(headings[0].index, 0);
      expect(headings[1].blockIndex, 0);
      expect(headings[1].index, 1);
      expect(headings[2].blockIndex, 2);
      expect(headings[2].index, 1);
    });
  });

  group('TOC indentation by depth', () {
    test('depth 0 entries have no extra indent', () {
      final chapters = {
        0: _chapter(0, 'Chapter', [_heading(1, 'H')]),
      };
      final result = buildTocFromHeadings(['Chapter'], chapters);

      final chapterEntry = result.first;
      expect(chapterEntry.depth, 0);
    });

    test('deeper entries have larger depth values', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'H1'),
          _heading(2, 'H2', blockIndex: 1),
          _heading(3, 'H3', blockIndex: 2),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[0].depth, lessThan(headings[1].depth));
      expect(headings[1].depth, lessThan(headings[2].depth));
    });

    test('entries at same heading level have same depth', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'A'),
          _heading(2, 'B', blockIndex: 1),
          _heading(2, 'C', blockIndex: 2),
          _heading(1, 'D', blockIndex: 3),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final headings = result.where((e) => e.depth > 0).toList();
      expect(headings[1].depth, headings[2].depth);
      expect(headings[0].depth, headings[3].depth);
    });
  });

  group('navigation from nested TOC entry', () {
    test('level-3 entry has blockIndex pointing to heading block', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _heading(1, 'Part'),
          _paragraph('text', blockIndex: 1),
          _heading(2, 'Section', blockIndex: 2),
          _paragraph('text', blockIndex: 3),
          _heading(3, 'Target Subsection', blockIndex: 4),
          _paragraph('text', blockIndex: 5),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final level3 = result.firstWhere(
        (e) => e.title == 'Target Subsection',
      );
      expect(level3.depth, 3);
      expect(level3.blockIndex, 4);
      expect(level3.index, 0);
    });

    test('level-2 entry blockIndex differs from chapter start', () {
      final chapters = {
        0: _chapter(0, 'Ch', [
          _paragraph('intro0'),
          _paragraph('intro1', blockIndex: 1),
          _paragraph('intro2', blockIndex: 2),
          _heading(1, 'H1', blockIndex: 3),
          _paragraph('body', blockIndex: 4),
          _heading(2, 'H2', blockIndex: 5),
        ]),
      };
      final result = buildTocFromHeadings(['Ch'], chapters);

      final h2 = result.firstWhere((e) => e.title == 'H2');
      expect(h2.blockIndex, 5);
      expect(h2.blockIndex, isNot(0));
    });

    test('blockIndex is consistent across chapters', () {
      final chapters = {
        0: _chapter(0, 'First', [
          _paragraph('p'),
          _heading(1, 'H-A', blockIndex: 1),
        ]),
        1: _chapter(1, 'Second', [
          _paragraph('p'),
          _paragraph('p', blockIndex: 1),
          _paragraph('p', blockIndex: 2),
          _heading(1, 'H-B', blockIndex: 3),
        ]),
      };
      final result = buildTocFromHeadings(['First', 'Second'], chapters);

      final ha = result.firstWhere((e) => e.title == 'H-A');
      final hb = result.firstWhere((e) => e.title == 'H-B');
      expect(ha.blockIndex, 1);
      expect(ha.index, 0);
      expect(hb.blockIndex, 3);
      expect(hb.index, 1);
    });
  });

  group('buildTocFromEpubToc blockIndex', () {
    test('epub entries default blockIndex to 0', () {
      final items = [
        {'title': 'Ch1', 'href': 'ch1.xhtml'},
        {'title': 'Ch2', 'href': 'ch2.xhtml'},
      ];
      final result = buildTocFromEpubToc(items);

      expect(result[0].blockIndex, 0);
      expect(result[1].blockIndex, 0);
    });
  });

  group('buildTocHierarchy blockIndex', () {
    test('numbered-title entries default blockIndex to 0', () {
      final result = buildTocHierarchy(['1 Chapter', '1.1 Sub', '2 Next']);

      for (final entry in result) {
        expect(entry.blockIndex, 0);
      }
    });
  });
}

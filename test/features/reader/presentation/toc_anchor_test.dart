import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/toc_hierarchy.dart';

void main() {
  group('TocEntry anchor', () {
    test('stores anchor from constructor', () {
      const entry = TocEntry(
        index: 0,
        title: 'Intro',
        depth: 0,
        isGroup: false,
        groupId: 0,
        anchor: 'section-intro',
      );
      expect(entry.anchor, 'section-intro');
    });

    test('anchor is null by default', () {
      const entry = TocEntry(
        index: 0,
        title: 'Chapter',
        depth: 0,
        isGroup: false,
        groupId: 0,
      );
      expect(entry.anchor, isNull);
    });
  });

  group('resolveTocAnchor', () {
    test('resolves chapter and paragraph from epubAnchors metadata', () {
      final metadata = <String, dynamic>{
        'epubAnchors': <String, dynamic>{
          'OEBPS/ch01.xhtml#section-intro': <String, dynamic>{
            'chapterIndex': 2,
            'paragraphIndex': 5,
          },
        },
        'epubChapterPaths': <String>[
          'OEBPS/ch00.xhtml',
          'OEBPS/ch01.xhtml',
          'OEBPS/ch02.xhtml',
        ],
      };
      final result = resolveTocAnchor(
        metadata: metadata,
        anchor: 'section-intro',
        chapterIndex: 1,
      );
      expect(result, isNotNull);
      expect(result!.chapterIndex, 2);
      expect(result.paragraphIndex, 5);
    });

    test('returns null when anchor is null', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{},
          'epubChapterPaths': <String>[],
        },
        anchor: null,
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when anchor is empty', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{},
          'epubChapterPaths': <String>[],
        },
        anchor: '',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when metadata is null', () {
      final result = resolveTocAnchor(
        metadata: null,
        anchor: 'some-anchor',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when epubAnchors is missing', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubChapterPaths': <String>['ch01.xhtml'],
        },
        anchor: 'some-anchor',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when epubChapterPaths is missing', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{'epubAnchors': <String, dynamic>{}},
        anchor: 'some-anchor',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when chapterIndex is out of bounds', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{},
          'epubChapterPaths': <String>['ch01.xhtml'],
        },
        anchor: 'some-anchor',
        chapterIndex: 5,
      );
      expect(result, isNull);
    });

    test('returns null when chapterIndex is negative', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{},
          'epubChapterPaths': <String>['ch01.xhtml'],
        },
        anchor: 'some-anchor',
        chapterIndex: -1,
      );
      expect(result, isNull);
    });

    test('returns null when anchor key not found in epubAnchors', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{
            'ch01.xhtml#other-anchor': <String, dynamic>{
              'chapterIndex': 0,
              'paragraphIndex': 2,
            },
          },
          'epubChapterPaths': <String>['ch01.xhtml'],
        },
        anchor: 'missing-anchor',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when anchor value is not a map', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{
            'ch01.xhtml#bad': 'not-a-map',
          },
          'epubChapterPaths': <String>['ch01.xhtml'],
        },
        anchor: 'bad',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('returns null when resolved indices are negative', () {
      final result = resolveTocAnchor(
        metadata: <String, dynamic>{
          'epubAnchors': <String, dynamic>{
            'ch01.xhtml#neg': <String, dynamic>{
              'chapterIndex': -1,
              'paragraphIndex': 0,
            },
          },
          'epubChapterPaths': <String>['ch01.xhtml'],
        },
        anchor: 'neg',
        chapterIndex: 0,
      );
      expect(result, isNull);
    });

    test('builds key from chapterPath#anchor', () {
      final metadata = <String, dynamic>{
        'epubAnchors': <String, dynamic>{
          'OEBPS/text/chapter2.xhtml#appendix-a': <String, dynamic>{
            'chapterIndex': 3,
            'paragraphIndex': 0,
          },
        },
        'epubChapterPaths': <String>[
          'OEBPS/text/chapter0.xhtml',
          'OEBPS/text/chapter1.xhtml',
          'OEBPS/text/chapter2.xhtml',
        ],
      };
      final result = resolveTocAnchor(
        metadata: metadata,
        anchor: 'appendix-a',
        chapterIndex: 2,
      );
      expect(result, isNotNull);
      expect(result!.chapterIndex, 3);
      expect(result.paragraphIndex, 0);
    });
  });

  group('buildTocFromEpubToc anchor extraction', () {
    test('extracts anchor from href with fragment', () {
      final items = [
        {
          'title': 'Chapter 1',
          'href': 'OEBPS/ch01.xhtml',
          'children': <Map<String, dynamic>>[],
        },
        {
          'title': 'Section A',
          'href': 'OEBPS/ch01.xhtml#section-a',
        },
        {
          'title': 'Section B',
          'href': 'OEBPS/ch02.xhtml#section-b',
        },
      ];
      final result = buildTocFromEpubToc(items);

      expect(result.length, 3);
      expect(result[0].anchor, isNull);
      expect(result[1].anchor, 'section-a');
      expect(result[2].anchor, 'section-b');
    });

    test('handles href without fragment', () {
      final items = [
        {'title': 'Chapter', 'href': 'chapter.xhtml'},
      ];
      final result = buildTocFromEpubToc(items);

      expect(result.length, 1);
      expect(result[0].anchor, isNull);
    });

    test('handles empty href', () {
      final items = [
        {'title': 'Chapter', 'href': ''},
      ];
      final result = buildTocFromEpubToc(items);

      expect(result.length, 1);
      expect(result[0].anchor, isNull);
    });

    test('handles missing href', () {
      final items = [
        {'title': 'Chapter'},
      ];
      final result = buildTocFromEpubToc(items);

      expect(result.length, 1);
      expect(result[0].anchor, isNull);
    });

    test('handles fragment-only href', () {
      final items = [
        {'title': 'Anchor', 'href': '#my-anchor'},
      ];
      final result = buildTocFromEpubToc(items);

      expect(result.length, 1);
      expect(result[0].anchor, 'my-anchor');
    });

    test('extracts anchors from nested children', () {
      final items = [
        {
          'title': 'Part 1',
          'href': 'part1.xhtml',
          'children': [
            {
              'title': 'Chapter 1',
              'href': 'ch01.xhtml#ch1',
            },
          ],
        },
      ];
      final result = buildTocFromEpubToc(items);

      expect(result.length, 2);
      expect(result[0].anchor, isNull);
      expect(result[1].anchor, 'ch1');
    });
  });
}

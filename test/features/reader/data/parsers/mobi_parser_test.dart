import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/mobi_parser.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

void main() {
  group('MobiHtmlParser', () {
    late MobiHtmlParser parser;

    setUp(() {
      parser = MobiHtmlParser();
    });

    test('parses heading tags into BlockType.heading', () {
      final blocks = parser.parse('<h1>Title</h1><p>Text</p>');
      expect(blocks, hasLength(2));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].text, 'Title');
      expect(blocks[1].type, BlockType.paragraph);
      expect(blocks[1].text, 'Text');
    });

    test('parses h2-h6 headings', () {
      final blocks = parser.parse('<h2>Chapter</h2>');
      expect(blocks, hasLength(1));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].text, 'Chapter');
    });

    test('parses blockquote into BlockType.quote', () {
      final blocks = parser.parse('<blockquote>Quoted text</blockquote>');
      expect(blocks, hasLength(1));
      expect(blocks[0].type, BlockType.quote);
      expect(blocks[0].text, 'Quoted text');
    });

    test('parses hr into BlockType.separator', () {
      final blocks = parser.parse('<p>Before</p><hr><p>After</p>');
      expect(blocks, hasLength(3));
      expect(blocks[1].type, BlockType.separator);
    });

    test('parses bold and italic into RichSpan', () {
      final blocks = parser.parse('<p><b>Bold</b> and <i>italic</i></p>');
      expect(blocks, hasLength(1));
      expect(blocks[0].richSpans, isNotNull);
      expect(blocks[0].richSpans!.length, greaterThanOrEqualTo(2));
      final bold = blocks[0].richSpans!.firstWhere((s) => s.text == 'Bold');
      expect(bold.bold, isTrue);
      final italic = blocks[0].richSpans!.firstWhere((s) => s.text == 'italic');
      expect(italic.italic, isTrue);
    });

    test('parses <strong> and <em> as bold and italic', () {
      final blocks = parser.parse('<p><strong>Bold</strong> <em>Italic</em></p>');
      expect(blocks, hasLength(1));
      final bold = blocks[0].richSpans!.firstWhere((s) => s.text == 'Bold');
      expect(bold.bold, isTrue);
      final italic = blocks[0].richSpans!.firstWhere((s) => s.text == 'Italic');
      expect(italic.italic, isTrue);
    });

    test('parses <sup> as superscript', () {
      final blocks = parser.parse('<p>x<sup>2</sup></p>');
      expect(blocks, hasLength(1));
      final sup = blocks[0].richSpans!.firstWhere((s) => s.text == '2');
      expect(sup.superscript, isTrue);
    });

    test('parses <a href> into RichSpan with href', () {
      final blocks = parser.parse('<p><a href="http://example.com">Link</a></p>');
      expect(blocks, hasLength(1));
      final link = blocks[0].richSpans!.firstWhere((s) => s.text == 'Link');
      expect(link.href, 'http://example.com');
    });

    test('converts <br> to newline in RichSpan', () {
      final blocks = parser.parse('<p>Line 1<br>Line 2</p>');
      expect(blocks, hasLength(1));
      final br = blocks[0].richSpans!.firstWhere((s) => s.text == '\n');
      expect(br, isNotNull);
    });

    test('decodes HTML entities', () {
      final blocks = parser.parse('<p>&amp; &lt; &gt; &nbsp;</p>');
      expect(blocks, hasLength(1));
      expect(blocks[0].text, contains('&'));
      expect(blocks[0].text, contains('<'));
      expect(blocks[0].text, contains('>'));
      expect(blocks[0].text, contains(' '));
    });

    test('decodes numeric character references', () {
      final blocks = parser.parse('<p>&#65; &#x42;</p>');
      expect(blocks, hasLength(1));
      expect(blocks[0].text, contains('A'));
      expect(blocks[0].text, contains('B'));
    });

    test('strips mbp:pagebreak tags', () {
      final blocks = parser.parse('<p>Before</p><mbp:pagebreak/><p>After</p>');
      expect(blocks, hasLength(2));
      expect(blocks[0].text, 'Before');
      expect(blocks[1].text, 'After');
    });

    test('strips DOCTYPE and comments', () {
      final blocks = parser.parse('<!DOCTYPE html><!-- comment --><p>Text</p>');
      expect(blocks, hasLength(1));
      expect(blocks[0].text, 'Text');
    });

    test('falls back to plain text for non-HTML input', () {
      final blocks = parser.parse('Just plain text without tags');
      expect(blocks, hasLength(1));
      expect(blocks[0].text, 'Just plain text without tags');
      expect(blocks[0].type, BlockType.paragraph);
    });

    test('handles nested inline tags', () {
      final blocks = parser.parse('<p><b><i>Bold italic</i></b></p>');
      expect(blocks, hasLength(1));
      expect(blocks[0].richSpans, isNotEmpty);
      final span = blocks[0].richSpans!.first;
      expect(span.bold, isTrue);
      expect(span.italic, isTrue);
    });

    test('handles empty input', () {
      final blocks = parser.parse('');
      expect(blocks, isEmpty);
    });

    test('handles self-closing tags', () {
      final blocks = parser.parse('<p>Text<br/></p>');
      expect(blocks, hasLength(1));
    });

    test('preserves block elements within text', () {
      final blocks = parser.parse('<div><p>Para 1</p><p>Para 2</p></div>');
      expect(blocks, isNotEmpty);
      final combined = blocks.map((b) => b.text).join(' ');
      expect(combined, contains('Para 1'));
      expect(combined, contains('Para 2'));
    });
  });

  group('MobiChapterSplitter', () {
    late MobiChapterSplitter splitter;

    setUp(() {
      splitter = MobiChapterSplitter();
    });

    test('returns single document chapter for empty blocks', () {
      final chapters = splitter.split(const []);
      expect(chapters, hasLength(1));
      expect(chapters[0].title, 'Документ');
    });

    test('returns single chapter when no break points found', () {
      final blocks = List.generate(
        5,
        (i) => ReaderBlock(index: i, text: 'Paragraph $i'),
      );
      final chapters = splitter.split(blocks);
      expect(chapters, hasLength(1));
      expect(chapters[0].blocks, hasLength(5));
    });

    test('splits on heading blocks', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Intro text'),
        const ReaderBlock(index: 1, text: 'Chapter 1', type: BlockType.heading),
        const ReaderBlock(index: 2, text: 'Text 1'),
        const ReaderBlock(index: 3, text: 'Chapter 2', type: BlockType.heading),
        const ReaderBlock(index: 4, text: 'Text 2'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters.length, greaterThanOrEqualTo(3));
      expect(chapters[0].title, 'Документ');
      expect(chapters[1].title, 'Chapter 1');
      expect(chapters[2].title, 'Chapter 2');
    });

    test('splits on separator blocks not near headings', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Part 1'),
        const ReaderBlock(index: 1, text: '', type: BlockType.separator),
        const ReaderBlock(index: 2, text: 'Part 2'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters.length, greaterThanOrEqualTo(2));
    });

    test('does not split on separator near heading', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Chapter 1', type: BlockType.heading),
        const ReaderBlock(index: 1, text: '', type: BlockType.separator),
        const ReaderBlock(index: 2, text: 'Text'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters.length, 1);
    });

    test('splits on Russian chapter patterns', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Глава 1'),
        const ReaderBlock(index: 1, text: 'Content here'),
        const ReaderBlock(index: 2, text: 'Глава 2'),
        const ReaderBlock(index: 3, text: 'More content'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters.length, greaterThanOrEqualTo(2));
    });

    test('splits on English chapter patterns', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Chapter 1'),
        const ReaderBlock(index: 1, text: 'Content'),
        const ReaderBlock(index: 2, text: 'Chapter 2'),
        const ReaderBlock(index: 3, text: 'More'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters.length, greaterThanOrEqualTo(2));
    });

    test('splits on part/prologue/epilogue patterns', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Пролог'),
        const ReaderBlock(index: 1, text: 'Story begins'),
        const ReaderBlock(index: 2, text: 'Глава 1'),
        const ReaderBlock(index: 3, text: 'Chapter content'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters.length, greaterThanOrEqualTo(2));
    });

    test('falls back to 80-block chunks when no patterns found', () {
      final blocks = List.generate(
        200,
        (i) => ReaderBlock(index: i, text: 'Paragraph $i'),
      );
      final chapters = splitter.split(blocks);
      expect(chapters.length, 3);
      expect(chapters[0].blocks.length, 80);
      expect(chapters[1].blocks.length, 80);
      expect(chapters[2].blocks.length, 40);
    });

    test('chapter indices are sequential', () {
      final blocks = [
        const ReaderBlock(index: 0, text: 'Chapter 1', type: BlockType.heading),
        const ReaderBlock(index: 1, text: 'Text 1'),
        const ReaderBlock(index: 2, text: 'Chapter 2', type: BlockType.heading),
        const ReaderBlock(index: 3, text: 'Text 2'),
      ];
      final chapters = splitter.split(blocks);
      for (var i = 0; i < chapters.length; i++) {
        expect(chapters[i].index, i);
      }
    });

    test('cleans title HTML tags', () {
      final blocks = [
        const ReaderBlock(index: 0, text: '<b>Chapter 1</b>', type: BlockType.heading),
        const ReaderBlock(index: 1, text: 'Text'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters[0].title, 'Chapter 1');
    });

    test('truncates very long titles', () {
      final longTitle = 'A' * 100;
      final blocks = [
        ReaderBlock(index: 0, text: longTitle, type: BlockType.heading),
        const ReaderBlock(index: 1, text: 'Text'),
      ];
      final chapters = splitter.split(blocks);
      expect(chapters[0].title.length, lessThanOrEqualTo(81));
    });
  });

  group('MobiCoverExtractor', () {
    late MobiCoverExtractor extractor;

    setUp(() {
      extractor = MobiCoverExtractor();
    });

    test('extracts JPEG cover by EXTH coverRecordIndex', () {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      const palmDb = PalmDb(
        name: 'Test',
        records: [
          PalmRecord(offset: 0, attributes: 0, uniqueId: 0),
          PalmRecord(offset: 100, attributes: 0, uniqueId: 1),
        ],
      );
      final fullBytes = Uint8List(200);
      fullBytes.setRange(100, 100 + jpegBytes.length, jpegBytes);

      final header = const MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0x40,
        firstImageRecordIndex: 0,
      );
      final metadata = const MobiMetadata(
        coverRecordIndex: 1,
        hasExth: true,
      );

      final result = extractor.extract(
        fullBytes: fullBytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );
      expect(result, isNotNull);
      expect(result![0], 0xFF);
      expect(result[1], 0xD8);
    });

    test('falls back to firstImageRecordIndex when no EXTH cover', () {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);
      const palmDb = PalmDb(
        name: 'Test',
        records: [
          PalmRecord(offset: 0, attributes: 0, uniqueId: 0),
          PalmRecord(offset: 100, attributes: 0, uniqueId: 1),
        ],
      );
      final fullBytes = Uint8List(200);
      fullBytes.setRange(100, 100 + pngBytes.length, pngBytes);

      final header = const MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0,
        firstImageRecordIndex: 1,
      );
      final metadata = const MobiMetadata();

      final result = extractor.extract(
        fullBytes: fullBytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );
      expect(result, isNotNull);
      expect(result![0], 0x89);
    });

    test('validates GIF magic bytes', () {
      final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0, 0, 0, 0]);
      const palmDb = PalmDb(
        name: 'Test',
        records: [
          PalmRecord(offset: 0, attributes: 0, uniqueId: 0),
          PalmRecord(offset: 100, attributes: 0, uniqueId: 1),
        ],
      );
      final fullBytes = Uint8List(200);
      fullBytes.setRange(100, 100 + gifBytes.length, gifBytes);

      final header = const MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0x40,
        firstImageRecordIndex: 0,
      );
      final metadata = const MobiMetadata(coverRecordIndex: 1, hasExth: true);

      final result = extractor.extract(
        fullBytes: fullBytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );
      expect(result, isNotNull);
      expect(result![0], 0x47);
    });

    test('returns null for non-image bytes', () {
      final textBytes = Uint8List.fromList([0x54, 0x65, 0x78, 0x74, 0, 0, 0, 0]);
      const palmDb = PalmDb(
        name: 'Test',
        records: [
          PalmRecord(offset: 0, attributes: 0, uniqueId: 0),
          PalmRecord(offset: 100, attributes: 0, uniqueId: 1),
        ],
      );
      final fullBytes = Uint8List(200);
      fullBytes.setRange(100, 100 + textBytes.length, textBytes);

      final header = const MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0x40,
        firstImageRecordIndex: 0,
      );
      final metadata = const MobiMetadata(coverRecordIndex: 1, hasExth: true);

      final result = extractor.extract(
        fullBytes: fullBytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );
      expect(result, isNull);
    });

    test('returns null when no cover record and no image records', () {
      const palmDb = PalmDb(
        name: 'Test',
        records: [
          PalmRecord(offset: 0, attributes: 0, uniqueId: 0),
        ],
      );
      final fullBytes = Uint8List(100);

      final header = const MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0,
        firstImageRecordIndex: 0,
      );
      final metadata = const MobiMetadata();

      final result = extractor.extract(
        fullBytes: fullBytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );
      expect(result, isNull);
    });

    test('returns null for record index out of bounds', () {
      const palmDb = PalmDb(
        name: 'Test',
        records: [
          PalmRecord(offset: 0, attributes: 0, uniqueId: 0),
        ],
      );
      final fullBytes = Uint8List(100);

      final header = const MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0x40,
        firstImageRecordIndex: 0,
      );
      final metadata = const MobiMetadata(coverRecordIndex: 99, hasExth: true);

      final result = extractor.extract(
        fullBytes: fullBytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );
      expect(result, isNull);
    });
  });

  group('MobiTextExtractor', () {
    test('extractBlocks handles non-HTML plain text', () {
      final extractor = MobiTextExtractor();
      final palmDb = const PalmDb(name: 'Test', records: []);
      const header = MobiHeader(
        compression: 2,
        textEncoding: 1252,
        textRecordCount: 1,
        recordSize: 4096,
        fullNameOffset: 0,
        fullNameLength: 0,
        exthFlags: 0,
        firstImageRecordIndex: 0,
      );
      expect(
        () => extractor.extractBlocks(
          fullBytes: Uint8List(0),
          palmDb: palmDb,
          header: header,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MobiHtmlParser edge cases', () {
    late MobiHtmlParser parser;

    setUp(() {
      parser = MobiHtmlParser();
    });

    test('handles malformed unclosed tags', () {
      final blocks = parser.parse('<p>Text without closing tag');
      expect(blocks, isNotEmpty);
      expect(blocks[0].text, contains('Text'));
    });

    test('handles multiple headings in sequence', () {
      final blocks = parser.parse('<h1>Ch1</h1><h2>Sub1</h2><p>Text</p><h1>Ch2</h1>');
      expect(blocks, hasLength(4));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[1].type, BlockType.heading);
      expect(blocks[3].type, BlockType.heading);
    });

    test('handles mixed inline and block tags', () {
      final blocks = parser.parse(
        '<h1>Title</h1><p><b>Bold</b> text</p><blockquote><i>Quote</i></blockquote>',
      );
      expect(blocks, hasLength(3));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[1].type, BlockType.paragraph);
      expect(blocks[2].type, BlockType.quote);
    });

    test('handles script and style tags as inline content', () {
      final blocks = parser.parse('<p>Text</p><script>alert("xss")</script><p>More</p>');
      expect(blocks.length, greaterThanOrEqualTo(2));
      final firstText = blocks.first.text;
      expect(firstText, 'Text');
    });

    test('handles very long HTML', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 100; i++) {
        buffer.write('<p>Paragraph $i with <b>bold</b> and <i>italic</i> text.</p>');
      }
      final blocks = parser.parse(buffer.toString());
      expect(blocks, hasLength(100));
    });

    test('extracts text from heading with nested tags', () {
      final blocks = parser.parse('<h1><b>Bold Title</b></h1>');
      expect(blocks, hasLength(1));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].text, 'Bold Title');
    });

    test('handles table-like content', () {
      final blocks = parser.parse('<table><tr><td>Cell 1</td><td>Cell 2</td></tr></table>');
      expect(blocks, isNotEmpty);
    });
  });
}

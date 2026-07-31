import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

void main() {
  group('ReaderBlock page-break fields', () {
    test('defaults to false when not specified', () {
      const block = ReaderBlock(index: 0, text: 'Hello');
      expect(block.pageBreakBefore, false);
      expect(block.pageBreakInsideAvoid, false);
    });

    test('pageBreakBefore true is set correctly', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Chapter heading',
        type: BlockType.heading,
        pageBreakBefore: true,
      );
      expect(block.pageBreakBefore, true);
      expect(block.pageBreakInsideAvoid, false);
    });

    test('pageBreakInsideAvoid true is set correctly', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Paragraph',
        pageBreakInsideAvoid: true,
      );
      expect(block.pageBreakBefore, false);
      expect(block.pageBreakInsideAvoid, true);
    });

    test('both flags can be true simultaneously', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Important section',
        pageBreakBefore: true,
        pageBreakInsideAvoid: true,
      );
      expect(block.pageBreakBefore, true);
      expect(block.pageBreakInsideAvoid, true);
    });
  });

  group('ReaderBlock toJson/fromJson', () {
    test('roundtrip preserves pageBreakBefore', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Test',
        pageBreakBefore: true,
      );
      final json = block.toJson();
      final restored = ReaderBlock.fromJson(json);
      expect(restored.pageBreakBefore, true);
      expect(restored.pageBreakInsideAvoid, false);
    });

    test('roundtrip preserves pageBreakInsideAvoid', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Test',
        pageBreakInsideAvoid: true,
      );
      final json = block.toJson();
      final restored = ReaderBlock.fromJson(json);
      expect(restored.pageBreakBefore, false);
      expect(restored.pageBreakInsideAvoid, true);
    });

    test('roundtrip preserves both flags', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Test',
        pageBreakBefore: true,
        pageBreakInsideAvoid: true,
      );
      final json = block.toJson();
      final restored = ReaderBlock.fromJson(json);
      expect(restored.pageBreakBefore, true);
      expect(restored.pageBreakInsideAvoid, true);
    });

    test('fromJson defaults to false when fields absent', () {
      final json = {
        'index': 0,
        'text': 'Test',
        'type': 'paragraph',
      };
      final restored = ReaderBlock.fromJson(json);
      expect(restored.pageBreakBefore, false);
      expect(restored.pageBreakInsideAvoid, false);
    });

    test('toJson omits false flags', () {
      const block = ReaderBlock(index: 0, text: 'Test');
      final json = block.toJson();
      expect(json.containsKey('pageBreakBefore'), false);
      expect(json.containsKey('pageBreakInsideAvoid'), false);
    });

    test('toJson includes true flags', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Test',
        pageBreakBefore: true,
        pageBreakInsideAvoid: true,
      );
      final json = block.toJson();
      expect(json['pageBreakBefore'], true);
      expect(json['pageBreakInsideAvoid'], true);
    });
  });

  group('ReaderBlock withImageUrl', () {
    test('preserves pageBreakBefore', () {
      const block = ReaderBlock(
        index: 0,
        text: '',
        type: BlockType.image,
        imageUrl: 'old.jpg',
        pageBreakBefore: true,
      );
      final updated = block.withImageUrl('new.jpg');
      expect(updated.pageBreakBefore, true);
      expect(updated.pageBreakInsideAvoid, false);
    });

    test('preserves pageBreakInsideAvoid', () {
      const block = ReaderBlock(
        index: 0,
        text: '',
        type: BlockType.image,
        imageUrl: 'old.jpg',
        pageBreakInsideAvoid: true,
      );
      final updated = block.withImageUrl('new.jpg');
      expect(updated.pageBreakBefore, false);
      expect(updated.pageBreakInsideAvoid, true);
    });
  });

  group('NormalizedBook chapter with page-break blocks', () {
    test('page-break flags survive full book roundtrip', () {
      const book = NormalizedBook(
        id: 'test',
        title: 'Test Book',
        authors: ['Author'],
        chapters: [
          ReaderChapter(
            index: 0,
            title: 'Chapter 1',
            blocks: [
              ReaderBlock(index: 0, text: 'Before'),
              ReaderBlock(
                index: 1,
                text: 'New Section',
                type: BlockType.heading,
                headingLevel: 1,
                pageBreakBefore: true,
              ),
              ReaderBlock(
                index: 2,
                text: 'Content that should stay with next block',
                pageBreakInsideAvoid: true,
              ),
              ReaderBlock(
                index: 3,
                text: 'Content that follows',
              ),
            ],
          ),
        ],
      );

      final json = book.toJson();
      final restored = NormalizedBook.fromJson(json);
      final blocks = restored.chapters[0].blocks;

      expect(blocks[0].pageBreakBefore, false);
      expect(blocks[0].pageBreakInsideAvoid, false);

      expect(blocks[1].pageBreakBefore, true);
      expect(blocks[1].pageBreakInsideAvoid, false);

      expect(blocks[2].pageBreakBefore, false);
      expect(blocks[2].pageBreakInsideAvoid, true);

      expect(blocks[3].pageBreakBefore, false);
      expect(blocks[3].pageBreakInsideAvoid, false);
    });
  });
}

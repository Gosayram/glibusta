import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  group('list block cache key', () {
    test('same content produces same hash', () {
      final a = [
        const ReaderBlock(index: 0, text: 'Item 1', type: BlockType.listItem),
        const ReaderBlock(index: 1, text: 'Item 2', type: BlockType.listItem),
      ];
      final b = [
        const ReaderBlock(index: 0, text: 'Item 1', type: BlockType.listItem),
        const ReaderBlock(index: 1, text: 'Item 2', type: BlockType.listItem),
      ];
      expect(hashListItemsForTest(a), equals(hashListItemsForTest(b)));
    });

    test('different content produces different hash', () {
      final a = [
        const ReaderBlock(index: 0, text: 'Item 1', type: BlockType.listItem),
        const ReaderBlock(index: 1, text: 'Item 2', type: BlockType.listItem),
      ];
      final b = [
        const ReaderBlock(index: 0, text: 'Item 1', type: BlockType.listItem),
        const ReaderBlock(index: 1, text: 'Different', type: BlockType.listItem),
      ];
      expect(hashListItemsForTest(a), isNot(hashListItemsForTest(b)));
    });

    test('null list produces stable hash', () {
      expect(hashListItemsForTest(null), equals(hashListItemsForTest(null)));
    });

    test('empty list produces stable hash', () {
      expect(hashListItemsForTest([]), equals(hashListItemsForTest([])));
    });

    test('null and empty produce same hash', () {
      expect(hashListItemsForTest(null), equals(hashListItemsForTest([])));
    });
  });
}

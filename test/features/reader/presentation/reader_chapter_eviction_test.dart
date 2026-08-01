import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';

ReaderChapter _chapter(int index) => ReaderChapter(
  index: index,
  title: 'Chapter $index',
  blocks: const [],
);

Map<int, ReaderChapter> _loadChapters(int count) => {
  for (var i = 0; i < count; i++) i: _chapter(i),
};

void main() {
  group('evictDistantChapters continuous mode backward cap', () {
    test('caps backward retention to ~10 chapters when keepAllBefore is true', () {
      final loaded = _loadChapters(50);
      final result = ReaderContentHelper.evictDistantChapters(
        25,
        loaded,
        keepAllBefore: true,
      );
      expect(result.containsKey(25), isTrue);
      expect(result.containsKey(15), isTrue);
      expect(result.containsKey(14), isFalse);
    });

    test('current chapter is always retained', () {
      final loaded = _loadChapters(50);
      for (final center in [0, 10, 25, 49]) {
        final result = ReaderContentHelper.evictDistantChapters(
          center,
          loaded,
          keepAllBefore: true,
        );
        expect(result.containsKey(center), isTrue, reason: 'center=$center');
      }
    });

    test('forward retention still works correctly', () {
      final loaded = _loadChapters(50);
      final result = ReaderContentHelper.evictDistantChapters(
        25,
        loaded,
        keepAllBefore: true,
      );
      expect(result.containsKey(28), isTrue);
      expect(result.containsKey(29), isFalse);
    });

    test('near start of book keeps from 0', () {
      final loaded = _loadChapters(50);
      final result = ReaderContentHelper.evictDistantChapters(
        3,
        loaded,
        keepAllBefore: true,
      );
      expect(result.containsKey(0), isTrue);
      expect(result.containsKey(3), isTrue);
      expect(result.containsKey(6), isTrue);
      expect(result.containsKey(7), isFalse);
    });

    test('near end of book evicts old backward chapters', () {
      final loaded = _loadChapters(500);
      final result = ReaderContentHelper.evictDistantChapters(
        499,
        loaded,
        keepAllBefore: true,
      );
      expect(result.containsKey(499), isTrue);
      expect(result.containsKey(489), isTrue);
      expect(result.containsKey(488), isFalse);
      expect(result.length, lessThanOrEqualTo(maxLoadedChapters));
    });

    test('non-continuous mode still uses original window', () {
      final loaded = _loadChapters(50);
      final result = ReaderContentHelper.evictDistantChapters(
        25,
        loaded,
      );
      expect(result.containsKey(25), isTrue);
      expect(result.containsKey(22), isTrue);
      expect(result.containsKey(28), isTrue);
      expect(result.containsKey(21), isFalse);
      expect(result.containsKey(29), isFalse);
    });
  });
}

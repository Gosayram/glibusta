import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/utils/author_normalizer.dart';

void main() {
  group('AuthorNormalizer.normalize', () {
    test('trims whitespace', () {
      expect(AuthorNormalizer.normalize('  Pushkin  '), 'Pushkin');
    });

    test('swaps "Last, First" to "First Last"', () {
      expect(AuthorNormalizer.normalize('Толстой, Лев'), 'Лев Толстой');
    });

    test('handles multiple comma parts', () {
      expect(AuthorNormalizer.normalize('Иванов, Пётр, Сергей'), 'Пётр Иванов');
    });

    test('normalizes multiple spaces', () {
      expect(AuthorNormalizer.normalize('Анна   Каренина'), 'Анна Каренина');
    });

    test('splits semicolons and joins with comma', () {
      final result = AuthorNormalizer.normalize('Пушкин; Лермонтов');
      expect(result, 'Пушкин, Лермонтов');
    });

    test('returns empty for empty string', () {
      expect(AuthorNormalizer.normalize(''), '');
    });

    test('returns empty for whitespace only', () {
      expect(AuthorNormalizer.normalize('   '), '');
    });

    test('single name unchanged', () {
      expect(AuthorNormalizer.normalize('Достоевский'), 'Достоевский');
    });
  });

  group('AuthorNormalizer.normalizeList', () {
    test('deduplicates same author', () {
      final result = AuthorNormalizer.normalizeList([
        'Толстой, Лев',
        'Толстой, Лев',
      ]);
      expect(result.length, 1);
    });

    test('does not deduplicate different authors', () {
      final result = AuthorNormalizer.normalizeList([
        'Толстой, Лев',
        'Толстой, Лёв',
      ]);
      expect(result.length, 2);
    });

    test('filters empty results', () {
      final result = AuthorNormalizer.normalizeList(['', '   ', 'Пушкин']);
      expect(result, ['Пушкин']);
    });

    test('preserves order of first occurrence', () {
      final result = AuthorNormalizer.normalizeList([
        'Пушкин',
        'Толстой',
        'Пушкин',
      ]);
      expect(result, ['Пушкин', 'Толстой']);
    });
  });

  group('AuthorNormalizer.sortKey', () {
    test('returns lowercase last name', () {
      expect(AuthorNormalizer.sortKey('Лев Толстой'), 'толстой');
    });

    test('returns lowercase single name', () {
      expect(AuthorNormalizer.sortKey('Пушкин'), 'пушкин');
    });
  });
}

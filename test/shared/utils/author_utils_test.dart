import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/utils/author_utils.dart';

void main() {
  group('normalizeAuthorForSort', () {
    test('removes comma from "Last, First"', () {
      expect(normalizeAuthorForSort('Tolstoy, Leo'), 'tolstoy leo');
    });

    test('swaps "First Last" to "Last First"', () {
      expect(normalizeAuthorForSort('Leo Tolstoy'), 'tolstoy leo');
    });

    test('normalizes multiple authors separated by semicolon', () {
      expect(
        normalizeAuthorForSort('Tolstoy, Leo; Dostoevsky, Fyodor'),
        'tolstoy leo; dostoevsky fyodor',
      );
    });

    test('returns empty string for null', () {
      expect(normalizeAuthorForSort(null), '');
    });

    test('returns empty string for empty string', () {
      expect(normalizeAuthorForSort(''), '');
    });

    test('returns empty string for whitespace-only', () {
      expect(normalizeAuthorForSort('   '), '');
    });

    test('single-word author stays unchanged (lowercased)', () {
      expect(normalizeAuthorForSort('Гоголь'), 'гоголь');
    });

    test('"Last First" without comma gets swapped', () {
      expect(normalizeAuthorForSort('Толстой Лев'), 'лев толстой');
    });

    test('trims whitespace', () {
      expect(normalizeAuthorForSort('  Tolstoy, Leo  '), 'tolstoy leo');
    });

    test('semicolon-separated with mixed formats', () {
      expect(
        normalizeAuthorForSort('Leo Tolstoy; Dostoevsky, Fyodor'),
        'tolstoy leo; dostoevsky fyodor',
      );
    });

    test('normalizes ё to е', () {
      expect(normalizeAuthorForSort('Алёшев'), 'алешев');
    });

    test('strips leading article "The"', () {
      expect(normalizeAuthorForSort('The Smith'), 'smith');
    });

    test('both formats produce identical key', () {
      expect(
        normalizeAuthorForSort('Asimov, Isaac'),
        normalizeAuthorForSort('Isaac Asimov'),
      );
    });
  });
}

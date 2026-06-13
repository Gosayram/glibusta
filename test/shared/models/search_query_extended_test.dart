import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/search_query.dart';

void main() {
  group('SearchFilters.copyWith', () {
    test('adds format', () {
      const f = SearchFilters();
      final updated = f.copyWith(format: BookFormat.epub);
      expect(updated.format, BookFormat.epub);
    });

    test('adds language', () {
      const f = SearchFilters();
      final updated = f.copyWith(language: 'en');
      expect(updated.language, 'en');
    });

    test('adds genre', () {
      const f = SearchFilters();
      final updated = f.copyWith(genre: 'sci-fi');
      expect(updated.genre, 'sci-fi');
    });

    test('clearFormat removes format', () {
      const f = SearchFilters(format: BookFormat.fb2);
      final updated = f.copyWith(clearFormat: true);
      expect(updated.format, isNull);
    });

    test('clearLanguage removes language', () {
      const f = SearchFilters(language: 'ru');
      final updated = f.copyWith(clearLanguage: true);
      expect(updated.language, isNull);
    });

    test('clearGenre removes genre', () {
      const f = SearchFilters(genre: 'detective');
      final updated = f.copyWith(clearGenre: true);
      expect(updated.genre, isNull);
    });

    test('no changes keeps same values', () {
      const f = SearchFilters(
        format: BookFormat.pdf,
        language: 'de',
        genre: 'fantasy',
      );
      final updated = f.copyWith();
      expect(updated.format, BookFormat.pdf);
      expect(updated.language, 'de');
      expect(updated.genre, 'fantasy');
    });
  });

  group('SearchFilters.hasFilters', () {
    test('empty has no filters', () {
      const f = SearchFilters();
      expect(f.hasFilters, isFalse);
    });

    test('only format', () {
      const f = SearchFilters(format: BookFormat.txt);
      expect(f.hasFilters, isTrue);
    });

    test('empty string language is not a filter', () {
      const f = SearchFilters(language: '  ');
      expect(f.hasFilters, isFalse);
    });

    test('empty string genre is not a filter', () {
      const f = SearchFilters(genre: '  ');
      expect(f.hasFilters, isFalse);
    });
  });

  group('SearchQuery', () {
    test('page defaults to 0', () {
      const q = SearchQuery(query: 'test');
      expect(q.page, 0);
    });

    test('page can be set', () {
      const q = SearchQuery(query: 'test', page: 5);
      expect(q.page, 5);
    });

    test('hasFilters with genre query', () {
      const q = SearchQuery(query: '', genre: 'fiction');
      expect(q.hasFilters, isTrue);
    });

    test('no filters means no filters', () {
      const q = SearchQuery(query: 'hello');
      expect(q.hasFilters, isFalse);
    });
  });
}

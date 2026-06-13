import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/search_query.dart';

void main() {
  group('SearchQuery', () {
    test('default values', () {
      const q = SearchQuery(query: 'test');
      expect(q.query, 'test');
      expect(q.author, isNull);
      expect(q.title, isNull);
      expect(q.series, isNull);
      expect(q.genre, isNull);
      expect(q.filters.hasFilters, isFalse);
      expect(q.page, 0);
    });

    test('hasFilters is false when no filters', () {
      const q = SearchQuery(query: 'test');
      expect(q.hasFilters, isFalse);
    });

    test('hasFilters is true when genre is set', () {
      const q = SearchQuery(query: 'test', genre: 'fiction');
      expect(q.hasFilters, isTrue);
    });

    test('hasFilters is true when author is set', () {
      const q = SearchQuery(query: 'test', author: 'Пушкин');
      expect(q.hasFilters, isTrue);
    });

    test('hasFilters is true when title is set', () {
      const q = SearchQuery(query: 'test', title: 'Onegin');
      expect(q.hasFilters, isTrue);
    });

    test('hasFilters is true when series is set', () {
      const q = SearchQuery(query: 'test', series: 'Harry Potter');
      expect(q.hasFilters, isTrue);
    });
  });

  group('SearchFilters', () {
    test('default hasFilters is false', () {
      const f = SearchFilters();
      expect(f.hasFilters, isFalse);
    });

    test('hasFilters with format', () {
      const f = SearchFilters(format: BookFormat.epub);
      expect(f.hasFilters, isTrue);
    });

    test('hasFilters with language', () {
      const f = SearchFilters(language: 'ru');
      expect(f.hasFilters, isTrue);
    });

    test('hasFilters with genre', () {
      const f = SearchFilters(genre: 'fiction');
      expect(f.hasFilters, isTrue);
    });

    test('copyWith preserves fields', () {
      const f = SearchFilters(
        format: BookFormat.fb2,
        language: 'ru',
        genre: 'sci-fi',
      );
      final updated = f.copyWith(language: 'en');
      expect(updated.format, BookFormat.fb2);
      expect(updated.language, 'en');
      expect(updated.genre, 'sci-fi');
    });

    test('copyWith clearFormat', () {
      const f = SearchFilters(format: BookFormat.epub);
      final updated = f.copyWith(clearFormat: true);
      expect(updated.format, isNull);
    });

    test('copyWith clearLanguage', () {
      const f = SearchFilters(language: 'ru');
      final updated = f.copyWith(clearLanguage: true);
      expect(updated.language, isNull);
    });

    test('copyWith clearGenre', () {
      const f = SearchFilters(genre: 'fiction');
      final updated = f.copyWith(clearGenre: true);
      expect(updated.genre, isNull);
    });
  });

  group('SearchResultPage', () {
    test('stores all fields', () {
      const page = SearchResultPage(
        books: [],
        totalCount: 0,
        currentPage: 0,
        totalPages: 0,
        hasNextPage: false,
      );
      expect(page.books, isEmpty);
      expect(page.hasNextPage, isFalse);
    });
  });

  group('SearchAuthorResult', () {
    test('stores fields', () {
      const r = SearchAuthorResult(id: '1', name: 'Пушкин', bookCount: 10);
      expect(r.id, '1');
      expect(r.name, 'Пушкин');
      expect(r.bookCount, 10);
    });

    test('bookCount can be null', () {
      const r = SearchAuthorResult(id: '2', name: 'Толстой');
      expect(r.bookCount, isNull);
    });
  });

  group('SearchAuthorsResultPage', () {
    test('stores authors list', () {
      const page = SearchAuthorsResultPage(
        authors: [
          SearchAuthorResult(id: '1', name: 'Пушкин'),
        ],
      );
      expect(page.authors.length, 1);
    });
  });
}

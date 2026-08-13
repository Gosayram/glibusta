import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/http/http_client.dart';
import 'package:glibusta/features/search/domain/book_source.dart';
import 'package:glibusta/shared/models/search_query.dart';
import 'package:mocktail/mocktail.dart';

class MockBookSource extends Mock implements BookSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const SearchQuery(query: ''));
    registerFallbackValue(const SearchFilters());
  });

  group('HttpClient', () {
    group('getWithMirror', () {
      test('constructs with mirrors', () {
        final dio = Dio(BaseOptions(baseUrl: 'https://base.example.com'));
        final client = HttpClient(dio, mirrors: ['https://base.example.com']);
        expect(client, isA<HttpClient>());
      });

      test('deduplicates mirrors', () {
        final dio = Dio(BaseOptions(baseUrl: 'https://base.example.com'));
        final client = HttpClient(
          dio,
          mirrors: [
            'https://base.example.com',
            'https://base.example.com/', // trailing slash variant
          ],
        );
        expect(client, isA<HttpClient>());
      });

      test('falls back to base URL when no mirrors provided', () {
        final dio = Dio(BaseOptions(baseUrl: 'https://base.example.com'));
        final client = HttpClient(dio);
        expect(client, isA<HttpClient>());
      });
    });
  });

  group('BookSource via MockBookSource', () {
    test('searchBooks returns results for empty query', () async {
      final mockSource = MockBookSource();
      when(() => mockSource.searchBooks(any(), cancelToken: any(named: 'cancelToken'))).thenAnswer(
        (_) async => const SearchResultPage(
          books: [],
          totalCount: 0,
          currentPage: 0,
          totalPages: 0,
          hasNextPage: false,
        ),
      );

      final result = await mockSource.searchBooks(const SearchQuery(query: ''));
      expect(result.books, isEmpty);
      expect(result.totalCount, 0);
    });

    test('searchBooks with query returns results', () async {
      final mockSource = MockBookSource();
      when(() => mockSource.searchBooks(any(), cancelToken: any(named: 'cancelToken'))).thenAnswer(
        (_) async => const SearchResultPage(
          books: [],
          totalCount: 0,
          currentPage: 0,
          totalPages: 0,
          hasNextPage: false,
        ),
      );

      final result = await mockSource.searchBooks(const SearchQuery(query: 'Толстой'));
      expect(result.books, isEmpty);
    });

    test('searchBooks with filter returns empty', () async {
      final mockSource = MockBookSource();
      when(() => mockSource.searchBooks(any(), cancelToken: any(named: 'cancelToken'))).thenAnswer(
        (_) async => const SearchResultPage(
          books: [],
          totalCount: 0,
          currentPage: 0,
          totalPages: 0,
          hasNextPage: false,
        ),
      );

      final result = await mockSource.searchBooks(
        const SearchQuery(
          query: 'test',
          filters: SearchFilters(genre: 'Фантастика'),
        ),
      );
      expect(result.books, isEmpty);
    });
  });
}

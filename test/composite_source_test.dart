import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:glibusta/core/errors/failures.dart';
import 'package:glibusta/features/search/data/composite_source.dart';
import 'package:glibusta/features/search/domain/book_source.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/search_query.dart';

class MockBookSource extends Mock implements BookSource {}

Book _makeBook(String id, String title) => Book(
      id: id,
      title: title,
      authorIds: const [],
      genreIds: const [],
      description: null,
      coverUrl: null,
      publishDate: null,
      availableFormats: const [],
      source: const BookSourceInfo(sourceId: 'test', sourceUrl: ''),
    );

void main() {
  late MockBookSource mockSource1;
  late MockBookSource mockSource2;
  late CompositeBookSource composite;

  setUpAll(() {
    registerFallbackValue(const SearchQuery(query: 'test'));
    registerFallbackValue(BookFormat.epub);
  });

  setUp(() {
    mockSource1 = MockBookSource();
    mockSource2 = MockBookSource();
    composite = CompositeBookSource([mockSource1, mockSource2]);
  });

  group('CompositeBookSource.searchBooks', () {
    test('returns first successful result', () async {
      final result = SearchResultPage(
        books: [_makeBook('1', 'Test Book')],
        totalCount: 1,
        currentPage: 0,
        totalPages: 1,
        hasNextPage: false,
      );

      when(() => mockSource1.searchBooks(any(), cancelToken: any(named: 'cancelToken')))
          .thenAnswer((_) async => result);

      final searchResult = await composite.searchBooks(
        const SearchQuery(query: 'test'),
      );

      expect(searchResult.books.length, 1);
      expect(searchResult.books.first.title, 'Test Book');
    });

    test('falls back to second source when first fails', () async {
      final result = SearchResultPage(
        books: [_makeBook('2', 'Fallback Book')],
        totalCount: 1,
        currentPage: 0,
        totalPages: 1,
        hasNextPage: false,
      );

      when(() => mockSource1.searchBooks(any(), cancelToken: any(named: 'cancelToken')))
          .thenThrow(Exception('Source 1 failed'));
      when(() => mockSource2.searchBooks(any(), cancelToken: any(named: 'cancelToken')))
          .thenAnswer((_) async => result);

      final searchResult = await composite.searchBooks(
        const SearchQuery(query: 'test'),
      );

      expect(searchResult.books.length, 1);
      expect(searchResult.books.first.title, 'Fallback Book');
    });

    test('throws SourceUnavailableFailure when all sources fail', () async {
      when(() => mockSource1.searchBooks(any(), cancelToken: any(named: 'cancelToken')))
          .thenThrow(Exception('Source 1 failed'));
      when(() => mockSource2.searchBooks(any(), cancelToken: any(named: 'cancelToken')))
          .thenThrow(Exception('Source 2 failed'));

      expect(
        () => composite.searchBooks(const SearchQuery(query: 'test')),
        throwsA(isA<SourceUnavailableFailure>()),
      );
    });
  });

  group('CompositeBookSource.getDownloadUrl', () {
    test('returns URL from first source that succeeds', () async {
      when(() => mockSource1.getDownloadUrl(any(), any()))
          .thenAnswer((_) async => 'https://example.com/b/1/epub');

      final url = await composite.getDownloadUrl('1', BookFormat.epub);
      expect(url, 'https://example.com/b/1/epub');
    });

    test('falls back to second source', () async {
      when(() => mockSource1.getDownloadUrl(any(), any()))
          .thenThrow(Exception('Failed'));
      when(() => mockSource2.getDownloadUrl(any(), any()))
          .thenAnswer((_) async => 'https://mirror.com/b/1/epub');

      final url = await composite.getDownloadUrl('1', BookFormat.epub);
      expect(url, 'https://mirror.com/b/1/epub');
    });
  });
}

@Tags(['live'])
@Timeout(Duration(seconds: 30))
library;

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/http/http_client.dart';
import 'package:glibusta/features/search/data/flibusta_source.dart';
import 'package:glibusta/shared/models/search_query.dart';

void main() {
  late HttpClient client;
  late FlibustaHtmlSource source;

  setUpAll(() async {
    await dotenv.load();
    final baseUrl = dotenv.get('BASE_URL');
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        responseType: ResponseType.plain,
        headers: {'User-Agent': 'Mozilla/5.0'},
      ),
    );
    client = HttpClient(dio);
    source = FlibustaHtmlSource(client);
  });

  group('Book search', () {
    test('returns results for Russian query', () async {
      final result = await source.searchBooks(const SearchQuery(query: 'Кинг'));
      expect(result.books, isNotEmpty);
      expect(result.books.length, greaterThanOrEqualTo(10));
      expect(result.totalCount, greaterThan(0));

      for (final b in result.books) {
        expect(b.id, isNotEmpty);
        expect(b.title, isNotEmpty, reason: 'title should not be empty');
        expect(b.authorNames, isNotEmpty, reason: 'authors should not be empty');
      }
    });

    test('returns results for Latin query', () async {
      final result = await source.searchBooks(const SearchQuery(query: 'Tolstoy'));
      expect(result.books, isNotEmpty);
      expect(result.books.first.title, isNotEmpty);
    });

    test('returns results for numeric query', () async {
      final result = await source.searchBooks(const SearchQuery(query: '1984'));
      expect(result.books, isNotEmpty);
    });

    test('empty query returns no results', () async {
      final result = await source.searchBooks(const SearchQuery(query: ''));
      expect(result.books, isEmpty);
    });

    test('book IDs are numeric', () async {
      final result = await source.searchBooks(const SearchQuery(query: 'test'));
      for (final b in result.books) {
        expect(int.tryParse(b.id), isNotNull, reason: 'id ${b.id} should be numeric');
      }
    });

    test('titles contain no mojibake', () async {
      final result = await source.searchBooks(const SearchQuery(query: 'Кинг'));
      for (final b in result.books) {
        final hasMojibake = b.title.contains('╨') || b.title.contains('╤') || b.title.contains('─');
        expect(hasMojibake, false, reason: 'title "${b.title}" contains mojibake');
      }
    });
  });

  group('Book details', () {
    test('fetches details for known book', () async {
      final details = await source.getBookDetails('52496');
      expect(details.book.title, isNotEmpty);
      expect(details.book.authorNames, isNotEmpty);
    });
  });
}

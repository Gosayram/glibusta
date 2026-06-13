import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/http/api_url_builder.dart';

void main() {
  late ApiUrlBuilder builder;

  setUp(() {
    builder = ApiUrlBuilder(host: 'flibusta.example.com');
  });

  group('bookSearch', () {
    test('constructs correct search URL', () {
      final uri = builder.bookSearch(query: 'Пушкин');
      expect(uri.scheme, 'https');
      expect(uri.host, 'flibusta.example.com');
      expect(uri.path, '/booksearch');
      expect(uri.queryParameters['ask'], 'Пушкин');
      expect(uri.queryParameters['page'], '0');
      expect(uri.queryParameters.containsKey('filter'), isFalse);
    });

    test('includes filter when specified', () {
      final uri = builder.bookSearch(query: 'test', filter: 'chb');
      expect(uri.queryParameters['chb'], 'on');
    });

    test('trims query', () {
      final uri = builder.bookSearch(query: '  hello  ');
      expect(uri.queryParameters['ask'], 'hello');
    });
  });

  group('specialized search URLs', () {
    test('bookSearchBooks uses chb filter', () {
      final uri = builder.bookSearchBooks(query: 'test');
      expect(uri.queryParameters['ask'], 'test');
    });

    test('bookSearchAuthors uses cha filter', () {
      final uri = builder.bookSearchAuthors(query: 'Пушкин');
      expect(uri.queryParameters['ask'], 'Пушкин');
    });

    test('bookSearchSeries uses chs filter', () {
      final uri = builder.bookSearchSeries(query: 'series');
      expect(uri.queryParameters['ask'], 'series');
    });

    test('bookSearchGenres uses chg filter', () {
      final uri = builder.bookSearchGenres(query: 'genre');
      expect(uri.queryParameters['ask'], 'genre');
    });
  });

  group('resource URLs', () {
    test('book', () {
      final uri = builder.book('12345');
      expect(uri.path, '/b/12345');
    });

    test('bookDownload', () {
      final uri = builder.bookDownload('12345', 'epub');
      expect(uri.path, '/b/12345/epub');
    });

    test('author', () {
      final uri = builder.author('100');
      expect(uri.path, '/a/100');
    });

    test('genre', () {
      final uri = builder.genre('5');
      expect(uri.path, '/g/5');
    });

    test('genrePage with order', () {
      final uri = builder.genrePage('5', order: 'd');
      expect(uri.path, '/g/5');
      expect(uri.queryParameters['order'], 'd');
    });

    test('series', () {
      final uri = builder.series('99');
      expect(uri.path, '/s/99');
    });

    test('popular', () {
      final uri = builder.popular();
      expect(uri.path, '/stat/b');
    });

    test('recent without filters', () {
      final uri = builder.recent();
      expect(uri.path, '/new');
      expect(uri.queryParameters.containsKey('lang'), isFalse);
      expect(uri.queryParameters.containsKey('type'), isFalse);
    });

    test('recent with lang filter', () {
      final uri = builder.recent(lang: 'ru');
      expect(uri.queryParameters['lang'], 'ru');
    });

    test('recent with type filter', () {
      final uri = builder.recent(type: 'fb2');
      expect(uri.queryParameters['type'], 'fb2');
    });

    test('genres', () {
      final uri = builder.genres();
      expect(uri.path, '/g');
    });

    test('cover', () {
      final uri = builder.cover('12345');
      expect(uri.path, contains('/cover.jpg'));
    });

    test('opdsPopular', () {
      final uri = builder.opdsPopular();
      expect(uri.path, '/opds/popular');
    });

    test('opdsRecent', () {
      final uri = builder.opdsRecent();
      expect(uri.path, '/opds/recent');
    });

    test('opdsSearch', () {
      final uri = builder.opdsSearch(query: 'test', searchType: 'books');
      expect(uri.path, '/opds/opensearch');
      expect(uri.queryParameters['searchTerm'], 'test');
      expect(uri.queryParameters['searchType'], 'books');
      expect(uri.queryParameters['pageNumber'], '0');
    });
  });

  group('custom scheme', () {
    test('uses custom scheme', () {
      final b = ApiUrlBuilder(host: 'example.com', scheme: 'http');
      final uri = b.book('1');
      expect(uri.scheme, 'http');
    });
  });
}

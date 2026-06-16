import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/search/domain/book_source.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/search_query.dart';

void main() {
  group('MockBookSource', () {
    test('returns empty results for search', () async {
      final source = MockBookSource();
      final result = await source.searchBooks(const SearchQuery(query: 'test'));

      expect(result.books, isEmpty);
      expect(result.hasNextPage, isFalse);
      expect(result.currentPage, 0);
    });

    test('returns mock book details', () async {
      final source = MockBookSource();
      final details = await source.getBookDetails('123');

      expect(details.book.id, '123');
      expect(details.book.title, 'Mock Book');
      expect(details.description, 'Mock description');
      expect(details.availableFormats, contains(BookFormat.fb2));
    });

    test('returns mock formats', () async {
      final source = MockBookSource();
      final formats = await source.getAvailableFormats('123');

      expect(
        formats,
        containsAll([BookFormat.fb2, BookFormat.epub, BookFormat.txt, BookFormat.mobi]),
      );
      expect(formats.length, 4);
    });

    test('returns mock download URL', () async {
      final source = MockBookSource();
      final url = await source.getDownloadUrl('123', BookFormat.fb2);

      expect(url, contains('123'));
      expect(url, contains('fb2'));
    });
  });

  group('SearchQuery', () {
    test('has default page of 0', () {
      const query = SearchQuery(query: 'test');
      expect(query.page, 0);
    });

    test('supports optional parameters', () {
      const query = SearchQuery(
        query: 'test',
        author: 'Tolstoy',
        title: 'War and Peace',
        series: 'Classics',
        genre: 'fiction',
        page: 2,
      );

      expect(query.author, 'Tolstoy');
      expect(query.title, 'War and Peace');
      expect(query.series, 'Classics');
      expect(query.genre, 'fiction');
      expect(query.page, 2);
    });
  });

  group('Book model', () {
    test('supports all format types', () {
      expect(BookFormat.values.length, 10);
      expect(BookFormat.values, contains(BookFormat.fb2));
      expect(BookFormat.values, contains(BookFormat.epub));
      expect(BookFormat.values, contains(BookFormat.txt));
      expect(BookFormat.values, contains(BookFormat.pdf));
      expect(BookFormat.values, contains(BookFormat.mobi));
      expect(BookFormat.values, contains(BookFormat.azw3));
      expect(BookFormat.values, contains(BookFormat.prc));
      expect(BookFormat.values, contains(BookFormat.rtf));
      expect(BookFormat.values, contains(BookFormat.djvu));
      expect(BookFormat.values, contains(BookFormat.unknown));
    });
  });

  group('HTML fixture files', () {
    test('search fixture exists and is valid HTML', () async {
      final file = File('test/fixtures/search_result.html');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('<html>'));
      expect(content, contains('/b/12345'));
      expect(content, contains('Test Book Title'));
    });

    test('multiple results fixture exists', () async {
      final file = File('test/fixtures/search/multiple_results.html');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('Мастер и Маргарита'));
      expect(content, contains('Преступление и наказание'));
      expect(content, contains('Война и мир'));
      expect(content, contains('Булгаков'));
    });

    test('book details fixture exists', () async {
      final file = File('test/fixtures/book_details/sample_book.html');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('<h1>Мастер и Маргарита</h1>'));
      expect(content, contains('.fb2'));
      expect(content, contains('.epub'));
      expect(content, contains('.txt'));
    });

    test('empty results fixture exists', () async {
      final file = File('test/fixtures/search/empty_results.html');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('Ничего не найдено'));
    });
  });
}

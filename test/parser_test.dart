import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/shared/models/search_query.dart';

void main() {
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
      expect(BookFormat.values.length, 13);
      expect(BookFormat.values, contains(BookFormat.fb2));
      expect(BookFormat.values, contains(BookFormat.epub));
      expect(BookFormat.values, contains(BookFormat.txt));
      expect(BookFormat.values, contains(BookFormat.pdf));
      expect(BookFormat.values, contains(BookFormat.mobi));
      expect(BookFormat.values, contains(BookFormat.azw3));
      expect(BookFormat.values, contains(BookFormat.prc));
      expect(BookFormat.values, contains(BookFormat.rtf));
      expect(BookFormat.values, contains(BookFormat.djvu));
      expect(BookFormat.values, contains(BookFormat.docx));
      expect(BookFormat.values, contains(BookFormat.cbz));
      expect(BookFormat.values, contains(BookFormat.cbr));
      expect(BookFormat.values, contains(BookFormat.unknown));
    });
  });

  group('Import format detection', () {
    test('routes macro-enabled Word documents through the DOCX parser', () {
      expect(detectBookFormat('book.docm'), BookFormat.docx);
      expect(formatForExtension('DOCM'), BookFormat.docx);
      expect(importableExtensions, contains('docm'));
    });

    test('picker exposes every parser-backed document and comic extension', () {
      expect(
        importableExtensions,
        containsAll(['docx', 'docm', 'cbz', 'cbr']),
      );
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

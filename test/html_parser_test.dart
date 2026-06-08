import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;

void main() {
  group('Flibusta HTML Parser (fixture-based)', () {
    group('Search results parsing', () {
      test('parses multiple search results from fixture', () async {
        final html =
            await File('test/fixtures/search/multiple_results.html')
                .readAsString();
        final document = parse(html);
        final bookElements =
            document.querySelectorAll('table.series tr');

        expect(bookElements.length, 3);

        final firstBookLinks =
            bookElements[0].querySelectorAll('a[href*="/b/"]');
        expect(firstBookLinks.first.text, 'Мастер и Маргарита');

        final firstAuthors =
            bookElements[0].querySelectorAll('a[href*="/a/"]');
        expect(firstAuthors.first.text, 'Булгаков М.А.');

        final secondBookLinks =
            bookElements[1].querySelectorAll('a[href*="/b/"]');
        expect(secondBookLinks.first.text, 'Преступление и наказание');

        final thirdBookLinks =
            bookElements[2].querySelectorAll('a[href*="/b/"]');
        expect(thirdBookLinks.first.text, 'Война и мир. Том 1');
      });

      test('extracts book IDs from href', () async {
        final html =
            await File('test/fixtures/search/multiple_results.html')
                .readAsString();
        final document = parse(html);
        final links = document.querySelectorAll('a[href*="/b/"]');

        final ids = links
            .map((a) => RegExp(r'/b/(\d+)')
                .firstMatch(a.attributes['href'] ?? ''))
            .whereType<RegExpMatch>()
            .map((m) => m.group(1))
            .toSet();

        expect(ids, containsAll(['12345', '67890', '11111']));
      });

      test('extracts download formats', () async {
        final html =
            await File('test/fixtures/search/multiple_results.html')
                .readAsString();
        final document = parse(html);
        final firstRow =
            document.querySelector('table.series tr');
        final downloadLinks =
            firstRow!.querySelectorAll('a[href*="/download/"]');

        final formats = downloadLinks.map((a) {
          final href = a.attributes['href'] ?? '';
          if (href.endsWith('.fb2')) return 'fb2';
          if (href.endsWith('.epub')) return 'epub';
          if (href.endsWith('.txt')) return 'txt';
          return null;
        }).whereType<String>().toList();

        expect(formats, containsAll(['fb2', 'epub', 'txt']));
      });

      test('handles empty results', () async {
        final html =
            await File('test/fixtures/search/empty_results.html')
                .readAsString();
        final document = parse(html);
        final bookElements =
            document.querySelectorAll('table.series tr');

        expect(bookElements, isEmpty);
      });

      test('handles single result', () async {
        final html =
            await File('test/fixtures/search/single_result.html')
                .readAsString();
        final document = parse(html);
        final bookElements =
            document.querySelectorAll('table.series tr');

        expect(bookElements.length, 1);

        final link =
            bookElements[0].querySelector('a[href*="/b/"]');
        expect(link?.text, 'Единственная книга');
      });

      test('extracts pagination info', () async {
        final html =
            await File('test/fixtures/search/multiple_results.html')
                .readAsString();
        final document = parse(html);
        final pagerLinks =
            document.querySelectorAll('.pager a');

        expect(pagerLinks.length, 2);

        final pages =
            pagerLinks.map((a) => a.text.trim()).toList();
        expect(pages, containsAll(['2', '3']));
      });
    });

    group('Book details parsing', () {
      test('parses full book details from fixture', () async {
        final html = await File(
                'test/fixtures/book_details/sample_book.html')
            .readAsString();
        final document = parse(html);

        final title =
            document.querySelector('h1')?.text.trim();
        expect(title, 'Мастер и Маргарита');

        final authors =
            document.querySelectorAll('a[href*="/a/"]');
        expect(authors.length, 1);
        expect(authors.first.text, 'Булгаков М.А.');

        final genres =
            document.querySelectorAll('a[href*="/g/"]');
        expect(genres.length, 2);
        expect(genres.map((g) => g.text),
            containsAll(['Классика', 'Роман']));

        final description =
            document.querySelector('.book_description')?.text;
        expect(description, isNotNull);
        expect(description, contains('Мастер и Маргарита'));
      });

      test('extracts download links with formats', () async {
        final html = await File(
                'test/fixtures/book_details/sample_book.html')
            .readAsString();
        final document = parse(html);

        final downloadLinks =
            document.querySelectorAll('a.dl');
        expect(downloadLinks.length, 4);

        final hrefs = downloadLinks
            .map((a) => a.attributes['href'] ?? '')
            .toList();
        expect(hrefs.any((h) => h.endsWith('.fb2')), isTrue);
        expect(hrefs.any((h) => h.endsWith('.epub')), isTrue);
        expect(hrefs.any((h) => h.endsWith('.txt')), isTrue);
        expect(hrefs.any((h) => h.endsWith('.mobi')), isTrue);
      });

      test('extracts cover image URL', () async {
        final html = await File(
                'test/fixtures/book_details/sample_book.html')
            .readAsString();
        final document = parse(html);

        final coverImg =
            document.querySelector('.book_cover img');
        expect(coverImg, isNotNull);
        expect(coverImg!.attributes['src'],
            contains('12345.jpg'));
      });

      test('handles book without cover', () async {
        final html = await File(
                'test/fixtures/book_details/no_cover.html')
            .readAsString();
        final document = parse(html);

        final coverImg =
            document.querySelector('.book_cover img');
        expect(coverImg, isNull);

        final title =
            document.querySelector('h1')?.text.trim();
        expect(title, 'Преступление и наказание');
      });
    });
  });
}

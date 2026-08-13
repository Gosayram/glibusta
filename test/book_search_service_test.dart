import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/book_search_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

NormalizedBook _makeBook(List<List<String>> chapterParagraphs) {
  var blockIndex = 0;
  final chapters = <ReaderChapter>[];
  for (var ci = 0; ci < chapterParagraphs.length; ci++) {
    final blocks = <ReaderBlock>[];
    for (final paragraph in chapterParagraphs[ci]) {
      blocks.add(ReaderBlock(index: blockIndex++, text: paragraph));
    }
    chapters.add(ReaderChapter(index: ci, title: 'Chapter $ci', blocks: blocks));
  }
  return NormalizedBook(
    id: 'test',
    title: 'Test Book',
    authors: const ['Author'],
    chapters: chapters,
  );
}

void main() {
  group('BookSearchService', () {
    group('search', () {
      test('finds matching paragraphs case-insensitively', () async {
        final book = _makeBook([
          ['Hello World', 'Flutter is great', 'Dart language'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = await service.search('flutter');
        expect(results, hasLength(1));
        expect(results.first.matchText, 'Flutter is great');
        expect(results.first.chapterIndex, 0);
        expect(results.first.paragraphIndex, 1);
        expect(results.first.chapterTitle, 'Chapter 0');
      });

      test('returns empty for empty query', () async {
        final book = _makeBook([
          ['Hello World'],
        ]);
        final service = BookSearchService(book, '/dummy');
        expect(await service.search(''), isEmpty);
        expect(await service.search('   '), isEmpty);
      });

      test('returns empty when no matches', () async {
        final book = _makeBook([
          ['Hello World'],
        ]);
        final service = BookSearchService(book, '/dummy');
        expect(await service.search('xyz'), isEmpty);
      });

      test('respects maxResults limit', () async {
        final paragraphs = List.generate(100, (i) => 'Match word in paragraph $i');
        final book = _makeBook([paragraphs]);
        final service = BookSearchService(book, '/dummy');
        final results = await service.search('match', maxResults: 5);
        expect(results, hasLength(5));
      });

      test('provides before and after context', () async {
        final book = _makeBook([
          ['Before paragraph', 'Target paragraph', 'After paragraph'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = await service.search('Target');
        expect(results.first.beforeContext, 'Before paragraph');
        expect(results.first.afterContext, 'After paragraph');
      });

      test('before context is empty for first paragraph', () async {
        final book = _makeBook([
          ['First paragraph', 'Second paragraph'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = await service.search('First');
        expect(results.first.beforeContext, '');
        expect(results.first.afterContext, 'Second paragraph');
      });

      test('after context is empty for last paragraph', () async {
        final book = _makeBook([
          ['First paragraph', 'Last paragraph'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = await service.search('Last');
        expect(results.first.beforeContext, 'First paragraph');
        expect(results.first.afterContext, '');
      });

      test('searches across multiple chapters', () async {
        final book = _makeBook([
          ['Chapter one text'],
          ['Chapter two text'],
          ['Chapter three text'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = await service.search('text');
        expect(results, hasLength(3));
        expect(results[0].chapterIndex, 0);
        expect(results[1].chapterIndex, 1);
        expect(results[2].chapterIndex, 2);
      });

      test('skips empty paragraphs', () {
        final book = _makeBook([
          ['Hello', '', '   ', 'World'],
        ]);
        final service = BookSearchService(book, '/dummy');
        expect(service.totalParagraphs, 2);
      });
    });

    group('cancel', () {
      test('cancelPending stops stale search', () async {
        final paragraphs = List.generate(10000, (i) => 'Word $i match');
        final book = _makeBook([paragraphs]);
        final service = BookSearchService(book, '/dummy');

        final future = service.search('match');
        service.cancelPending();
        final results = await future;
        expect(results, isEmpty);
      });
    });

    group('suggestions', () {
      test('returns matching snippets', () {
        final book = _makeBook([
          ['The quick brown fox jumps over the lazy dog'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = service.suggestions('quick');
        expect(results, hasLength(1));
        expect(results.first, contains('quick'));
      });

      test('returns empty for empty prefix', () {
        final book = _makeBook([
          ['Hello World'],
        ]);
        final service = BookSearchService(book, '/dummy');
        expect(service.suggestions(''), isEmpty);
        expect(service.suggestions('   '), isEmpty);
      });

      test('respects maxSuggestions limit', () {
        final paragraphs = List.generate(
          20,
          (i) => 'UniqueWord$i appears in paragraph $i with UniqueWord$i',
        );
        final book = _makeBook([paragraphs]);
        final service = BookSearchService(book, '/dummy');
        final results = service.suggestions('Unique', maxSuggestions: 3);
        expect(results, hasLength(3));
      });

      test('deduplicates identical snippets', () {
        final book = _makeBook([
          ['Same text here', 'Same text here'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = service.suggestions('Same');
        expect(results, hasLength(1));
      });

      test('adds ellipsis for deep matches', () {
        final longText = 'AAAA BBBB CCCC DDDD EEEE FFFF GGGG HIII match target';
        final book = _makeBook([
          [longText],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = service.suggestions('match');
        expect(results.first, startsWith('…'));
      });

      test('no ellipsis for early matches', () {
        final book = _makeBook([
          ['match is here'],
        ]);
        final service = BookSearchService(book, '/dummy');
        final results = service.suggestions('match');
        expect(results.first, isNot(startsWith('…')));
      });
    });

    group('totalParagraphs', () {
      test('counts non-empty paragraphs across chapters', () {
        final book = _makeBook([
          ['A', 'B'],
          ['C', '', 'D'],
        ]);
        final service = BookSearchService(book, '/dummy');
        expect(service.totalParagraphs, 4);
      });

      test('returns 0 for empty book', () {
        final book = _makeBook([]);
        final service = BookSearchService(book, '/dummy');
        expect(service.totalParagraphs, 0);
      });
    });
  });
}

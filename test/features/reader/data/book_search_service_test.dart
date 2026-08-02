import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/book_search_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

NormalizedBook _testBook() {
  return const NormalizedBook(
    id: 'test',
    title: 'Test Book',
    authors: ['Author'],
    chapters: [
      ReaderChapter(
        index: 0,
        title: 'Chapter One',
        blocks: [
          ReaderBlock(index: 0, text: 'The cat sat on the mat.'),
          ReaderBlock(index: 1, text: 'The Cat sat on a castle.'),
          ReaderBlock(index: 2, text: 'A category of cats.'),
        ],
      ),
      ReaderChapter(
        index: 1,
        title: 'Chapter Two',
        blocks: [
          ReaderBlock(index: 0, text: 'The dog ran fast.'),
          ReaderBlock(index: 1, text: 'Knowledge is power.'),
        ],
      ),
    ],
  );
}

void main() {
  late BookSearchService service;

  setUp(() {
    service = BookSearchService(_testBook(), '/dummy');
  });

  group('literal search', () {
    test('case-insensitive finds all variants', () async {
      final results = await service.search('cat');
      expect(results, hasLength(3));
      expect(results.every((r) => r.chapterIndex == 0), isTrue);
    });

    test('case-sensitive respects case', () async {
      final results = await service.search('cat', matchCase: true);
      expect(results, hasLength(2));
      expect(results[0].matchText, 'The cat sat on the mat.');
      expect(results[1].matchText, 'A category of cats.');
    });

    test('case-sensitive "Cat" finds only capitalized', () async {
      final results = await service.search('Cat', matchCase: true);
      expect(results, hasLength(1));
      expect(results[0].matchText, 'The Cat sat on a castle.');
    });

    test('empty query returns empty', () async {
      expect(await service.search(''), isEmpty);
      expect(await service.search('   '), isEmpty);
    });

    test('chapter scope filters to one chapter', () async {
      final results = await service.search('the', chapterIndex: 1);
      expect(results, hasLength(1));
      expect(results[0].chapterIndex, 1);
    });
  });

  group('whole-word search', () {
    test('finds standalone words but not substrings', () async {
      final results = await service.search('cat', wholeWord: true);
      // "cat" in block 0 is standalone, "Cat" in block 1 is standalone (CI),
      // "category" and "cats" in block 2 are NOT standalone.
      expect(results, hasLength(2));
      expect(results[0].matchText, 'The cat sat on the mat.');
      expect(results[1].matchText, 'The Cat sat on a castle.');
    });

    test('case-sensitive whole-word', () async {
      final results = await service.search(
        'Cat',
        wholeWord: true,
        matchCase: true,
      );
      expect(results, hasLength(1));
      expect(results[0].matchText, 'The Cat sat on a castle.');
    });

    test('whole-word excludes "category" and "cats"', () async {
      final ci = await service.search('cat');
      final ww = await service.search('cat', wholeWord: true);
      expect(ci.length, greaterThan(ww.length));
    });
  });

  group('regex search', () {
    test('word alternation', () async {
      final results = await service.search('cat|dog', useRegex: true);
      expect(results, hasLength(4));
    });

    test('anchored pattern', () async {
      final results = await service.search(r'^The', useRegex: true);
      expect(results, hasLength(3));
    });

    test('case-sensitive regex', () async {
      final results = await service.search(
        r'^The',
        useRegex: true,
        matchCase: true,
      );
      expect(results, hasLength(3));
    });

    test('invalid regex returns empty without crash', () async {
      expect(await service.search('[invalid', useRegex: true), isEmpty);
    });

    test('regex with quantifiers', () async {
      final results = await service.search('cat.+', useRegex: true);
      expect(results, hasLength(3));
    });
  });

  group('cancellation', () {
    test('cancelPending prevents stale results', () async {
      final slowBook = NormalizedBook(
        id: 'big',
        title: 'Big',
        authors: const [],
        chapters: [
          ReaderChapter(
            index: 0,
            title: 'C',
            blocks: List.generate(
              600,
              (i) => ReaderBlock(index: i, text: 'word $i cat'),
            ),
          ),
        ],
      );
      final slowService = BookSearchService(slowBook, '/dummy');
      final searchFuture = slowService.search('cat');
      slowService.cancelPending();
      final results = await searchFuture;
      expect(results, isEmpty);
    });
  });

  group('suggestions', () {
    test('returns matching snippets', () {
      final s = service.suggestions('cat');
      expect(s, isNotEmpty);
    });

    test('empty prefix returns empty', () {
      expect(service.suggestions(''), isEmpty);
      expect(service.suggestions('   '), isEmpty);
    });
  });
}

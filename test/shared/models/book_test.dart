import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  group('Book', () {
    test('displayAuthor uses authorNames', () {
      const book = Book(
        id: '1',
        title: 'Test',
        authorIds: ['a1', 'a2'],
        authorNames: ['Пушкин', 'Толстой'],
        genreIds: [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: [],
        source: BookSourceInfo(sourceId: 's', sourceUrl: 'u'),
      );
      expect(book.displayAuthor, 'Пушкин, Толстой');
    });

    test('displayAuthor falls back to first authorId', () {
      const book = Book(
        id: '1',
        title: 'Test',
        authorIds: ['a1'],
        genreIds: [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: [],
        source: BookSourceInfo(sourceId: 's', sourceUrl: 'u'),
      );
      expect(book.displayAuthor, 'a1');
    });

    test('displayAuthor returns empty when no authors', () {
      const book = Book(
        id: '1',
        title: 'Test',
        authorIds: [],
        genreIds: [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: [],
        source: BookSourceInfo(sourceId: 's', sourceUrl: 'u'),
      );
      expect(book.displayAuthor, '');
    });

    test('readingStatusLabel returns correct Russian label', () {
      Book makeBook(ReadingStatus s) => Book(
        id: '1',
        title: 'T',
        authorIds: [],
        genreIds: [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: [],
        source: const BookSourceInfo(sourceId: 's', sourceUrl: 'u'),
        readingStatus: s,
      );

      expect(makeBook(ReadingStatus.none).readingStatusLabel, '');
      expect(makeBook(ReadingStatus.wantToRead).readingStatusLabel, 'Хочу прочитать');
      expect(makeBook(ReadingStatus.reading).readingStatusLabel, 'Читаю');
      expect(makeBook(ReadingStatus.finished).readingStatusLabel, 'Прочитано');
      expect(makeBook(ReadingStatus.dropped).readingStatusLabel, 'Брошено');
    });
  });

  group('ReadingStatusExtension', () {
    test('label returns correct Russian text', () {
      expect(ReadingStatus.none.label, 'Без статуса');
      expect(ReadingStatus.wantToRead.label, 'Хочу прочитать');
      expect(ReadingStatus.reading.label, 'Читаю');
      expect(ReadingStatus.finished.label, 'Прочитано');
      expect(ReadingStatus.dropped.label, 'Брошено');
    });
  });

  group('BookFormat', () {
    test('has all expected values', () {
      expect(BookFormat.values, contains(BookFormat.fb2));
      expect(BookFormat.values, contains(BookFormat.epub));
      expect(BookFormat.values, contains(BookFormat.pdf));
      expect(BookFormat.values, contains(BookFormat.txt));
      expect(BookFormat.values, contains(BookFormat.mobi));
      expect(BookFormat.values, contains(BookFormat.rtf));
      expect(BookFormat.values, contains(BookFormat.djvu));
      expect(BookFormat.values, contains(BookFormat.unknown));
    });
  });

  group('Author', () {
    test('stores fields correctly', () {
      const author = Author(
        id: 'a1',
        name: 'Пушкин',
        bookIds: ['b1', 'b2'],
      );
      expect(author.id, 'a1');
      expect(author.name, 'Пушкин');
      expect(author.bookIds.length, 2);
    });
  });

  group('BookSourceInfo', () {
    test('stores sourceId and sourceUrl', () {
      const info = BookSourceInfo(
        sourceId: 'flibusta',
        sourceUrl: 'https://flibusta.example.com/b/1',
      );
      expect(info.sourceId, 'flibusta');
      expect(info.sourceUrl, contains('flibusta'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  group('library reading-status filter', () {
    late final List<Book> books;

    setUpAll(() {
      books = [
        const Book(
          id: '1',
          title: 'Unread Book',
          authorIds: [],
          genreIds: [],
          description: null,
          coverUrl: null,
          publishDate: null,
          availableFormats: [BookFormat.epub],
          source: BookSourceInfo(sourceId: 'test', sourceUrl: ''),
        ),
        const Book(
          id: '2',
          title: 'Reading Book',
          authorIds: [],
          genreIds: [],
          description: null,
          coverUrl: null,
          publishDate: null,
          availableFormats: [BookFormat.epub],
          source: BookSourceInfo(sourceId: 'test', sourceUrl: ''),
          readingStatus: ReadingStatus.reading,
        ),
        const Book(
          id: '3',
          title: 'Finished Book',
          authorIds: [],
          genreIds: [],
          description: null,
          coverUrl: null,
          publishDate: null,
          availableFormats: [BookFormat.epub],
          source: BookSourceInfo(sourceId: 'test', sourceUrl: ''),
          readingStatus: ReadingStatus.finished,
        ),
      ];
    });

    // Mirrors the filter in library_screen.dart:274-275
    List<Book> applyFilter(List<Book> source, ReadingStatus? status) {
      var filtered = source;
      if (status != null) {
        filtered = filtered.where((b) => b.readingStatus == status).toList(growable: false);
      }
      return filtered;
    }

    // Mirrors the chip toggle at library_screen.dart:484-512
    ReadingStatus? toggle(ReadingStatus? current, ReadingStatus next) =>
        current == next ? null : next;

    test('null filter shows all books', () {
      final filtered = applyFilter(books, null);
      expect(filtered.length, 3);
    });

    test('filtering by ReadingStatus.none shows only unread books', () {
      final filtered = applyFilter(books, ReadingStatus.none);
      expect(filtered.length, 1);
      expect(filtered.single.title, 'Unread Book');
    });

    test('filtering by ReadingStatus.reading shows only currently reading', () {
      final filtered = applyFilter(books, ReadingStatus.reading);
      expect(filtered.length, 1);
      expect(filtered.single.title, 'Reading Book');
    });

    test('filtering by ReadingStatus.finished shows only finished books', () {
      final filtered = applyFilter(books, ReadingStatus.finished);
      expect(filtered.length, 1);
      expect(filtered.single.title, 'Finished Book');
    });

    test('filter excludes books with other statuses', () {
      final filtered = applyFilter(books, ReadingStatus.finished);
      expect(filtered.any((b) => b.readingStatus == ReadingStatus.none), isFalse);
      expect(filtered.any((b) => b.readingStatus == ReadingStatus.reading), isFalse);
    });

    group('chip toggle', () {
      test('clicking an inactive chip activates it', () {
        expect(toggle(null, ReadingStatus.reading), ReadingStatus.reading);
        expect(
          toggle(ReadingStatus.none, ReadingStatus.reading),
          ReadingStatus.reading,
        );
      });

      test('clicking the active chip clears the filter back to null', () {
        expect(toggle(ReadingStatus.reading, ReadingStatus.reading), isNull);
        expect(toggle(ReadingStatus.finished, ReadingStatus.finished), isNull);
      });
    });

    test('cleared filter (null) shows all books again', () {
      var status = ReadingStatus.reading as ReadingStatus?;
      expect(applyFilter(books, status).length, 1);
      status = toggle(status, ReadingStatus.reading); // clear
      expect(status, isNull);
      expect(applyFilter(books, status).length, 3);
    });
  });
}

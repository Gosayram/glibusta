import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/presentation/library_sort.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  Book book({
    required String id,
    required String title,
    List<String> authors = const [],
    DateTime? added,
  }) => Book(
    id: id,
    title: title,
    authorIds: const [],
    authorNames: authors,
    genreIds: const [],
    description: null,
    coverUrl: null,
    publishDate: null,
    dateAdded: added,
    availableFormats: const [],
    source: const BookSourceInfo(sourceId: '', sourceUrl: ''),
  );

  group('sortLibraryBooks', () {
    final books = [
      book(id: 'z', title: 'Zoo', authors: ['Маяковский'], added: DateTime(2025)),
      book(id: 'a', title: 'alpha', authors: ['Акунин'], added: DateTime(2025, 2)),
      book(id: 'm', title: 'Middle', added: DateTime(2024)),
    ];

    test('orders newest imports first without changing input', () {
      expect(
        sortLibraryBooks(books, LibrarySort.recentlyAdded).map((book) => book.id),
        ['a', 'z', 'm'],
      );
      expect(books.map((book) => book.id), ['z', 'a', 'm']);
    });

    test('orders title case-insensitively', () {
      expect(sortLibraryBooks(books, LibrarySort.title).map((book) => book.id), ['a', 'm', 'z']);
    });

    test('orders authors and uses id when an author is equal', () {
      final tiedAuthors = [
        book(id: 'b', title: 'Second', authors: ['Same']),
        book(id: 'a', title: 'First', authors: ['same']),
      ];

      expect(sortLibraryBooks(tiedAuthors, LibrarySort.author).map((book) => book.id), ['a', 'b']);
    });
  });
}

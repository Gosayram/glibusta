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

    test('normalizes comma format for consistent sorting', () {
      final mixed = [
        book(id: '1', title: 'Book A', authors: ['Толстой, Лев']),
        book(id: '2', title: 'Book B', authors: ['Толстой Лев']),
        book(id: '3', title: 'Book C', authors: ['Блок Александр']),
      ];
      final sorted = sortLibraryBooks(mixed, LibrarySort.author);
      // 'Блок Александр' → swapped → 'александр блок'
      // 'Толстой Лев' → swapped → 'лев толстой'
      // 'Толстой, Лев' → comma removed → 'толстой лев'
      expect(sorted.map((b) => b.id), ['3', '2', '1']);
    });

    test('normalizes ё→е for Russian sorting', () {
      final mixed = [
        book(id: '1', title: 'A', authors: ['Алёшев']),
        book(id: '2', title: 'B', authors: ['Алешев']),
      ];
      final sorted = sortLibraryBooks(mixed, LibrarySort.author);
      // Should be equal → tie-break by id
      expect(sorted.map((b) => b.id), ['1', '2']);
    });

    test('strips leading articles for sorting', () {
      final mixed = [
        book(id: '1', title: 'A', authors: ['The Smith']),
        book(id: '2', title: 'B', authors: ['Anderson']),
      ];
      final sorted = sortLibraryBooks(mixed, LibrarySort.author);
      // "The Smith" → "smith" should come after "Anderson" → "anderson"
      expect(sorted.map((b) => b.id), ['2', '1']);
    });

    test('comma and non-comma same order sort together', () {
      final mixed = [
        book(id: '1', title: 'A', authors: ['Asimov, Isaac']),
        book(id: '2', title: 'B', authors: ['Adams Douglas']),
        book(id: '3', title: 'C', authors: ['Asimov Isaac']),
      ];
      final sorted = sortLibraryBooks(mixed, LibrarySort.author);
      // 'Asimov, Isaac' → 'asimov isaac'
      // 'Adams Douglas' → swapped → 'douglas adams'
      // 'Asimov Isaac' → swapped → 'isaac asimov'
      expect(sorted.map((b) => b.id), ['1', '2', '3']);
    });

    test('progress sort is DB-level only and preserves input order', () {
      final input = [
        book(id: 'a', title: 'A'),
        book(id: 'b', title: 'B'),
      ];
      final sorted = sortLibraryBooks(input, LibrarySort.progress);
      expect(sorted.map((b) => b.id), ['a', 'b']);
    });
  });

  group('LibrarySort.progress', () {
    test('has correct label', () {
      expect(LibrarySort.progress.label, 'По прогрессу');
    });

    test('is included in all values', () {
      expect(LibrarySort.values, contains(LibrarySort.progress));
    });
  });
}

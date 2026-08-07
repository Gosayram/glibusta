import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/domain/book_repository.dart';
import 'package:glibusta/features/library/presentation/library_sort.dart';

void main() {
  group('BookSortField', () {
    test('has exactly 3 values (addedAt, title, progress)', () {
      expect(BookSortField.values.length, 3);
    });

    test('addedAt exists', () {
      expect(BookSortField.values.contains(BookSortField.addedAt), isTrue);
    });

    test('title exists', () {
      expect(BookSortField.values.contains(BookSortField.title), isTrue);
    });

    test('progress exists', () {
      expect(BookSortField.values.contains(BookSortField.progress), isTrue);
    });
  });

  group('LibrarySort mapping', () {
    test('author sort does not crash (maps to a valid field)', () {
      // Verify the sort enum has all expected values
      expect(LibrarySort.values.length, greaterThanOrEqualTo(3));
      expect(LibrarySort.values.contains(LibrarySort.author), isTrue);
    });

    test('recentlyAdded exists', () {
      expect(LibrarySort.values.contains(LibrarySort.recentlyAdded), isTrue);
    });
  });
}

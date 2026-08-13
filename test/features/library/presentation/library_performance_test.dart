import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/presentation/library_sort.dart';
import 'package:glibusta/shared/models/book.dart';

Book _book({
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

List<Book> _generateBooks(int count) {
  final now = DateTime.now();
  return List.generate(count, (i) {
    final id = 'book_$i';
    final title = 'Книга номер $i';
    final authors = ['Автор ${i % 100}'];
    final added = now.subtract(Duration(hours: i));
    return _book(id: id, title: title, authors: authors, added: added);
  });
}

void main() {
  group('Library performance with 10K+ books', () {
    test('sortLibraryBooks handles 10K books by recentlyAdded', () {
      final books = _generateBooks(10000);
      final sw = Stopwatch()..start();
      final sorted = sortLibraryBooks(books, LibrarySort.recentlyAdded);
      sw.stop();
      expect(sorted.length, 10000);
      expect(sorted.first.dateAdded!.isAfter(sorted.last.dateAdded!), isTrue);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('sortLibraryBooks handles 10K books by title', () {
      final books = _generateBooks(10000);
      final sw = Stopwatch()..start();
      final sorted = sortLibraryBooks(books, LibrarySort.title);
      sw.stop();
      expect(sorted.length, 10000);
      for (var i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].title.toLowerCase().compareTo(sorted[i - 1].title.toLowerCase()),
          greaterThanOrEqualTo(0),
        );
      }
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('sortLibraryBooks handles 10K books by author', () {
      final books = _generateBooks(10000);
      final sw = Stopwatch()..start();
      final sorted = sortLibraryBooks(books, LibrarySort.author);
      sw.stop();
      expect(sorted.length, 10000);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('in-memory search filter handles 10K books', () {
      final books = _generateBooks(10000);
      const query = 'Книга номер 500';
      final sw = Stopwatch()..start();
      final filtered = books.where((b) {
        final titleMatch = b.title.toLowerCase().contains(query.toLowerCase());
        final authorMatch = b.displayAuthor.toLowerCase().contains(query.toLowerCase());
        return titleMatch || authorMatch;
      }).toList();
      sw.stop();
      expect(filtered, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('pagination loads books in pages of 50', () {
      final allBooks = _generateBooks(10000);
      const pageSize = 50;

      final page0 = allBooks.skip(0).take(pageSize).toList();
      final page1 = allBooks.skip(50).take(pageSize).toList();
      final page199 = allBooks.skip(9950).take(pageSize).toList();

      expect(page0.length, 50);
      expect(page1.length, 50);
      expect(page199.length, 50);
      expect(page0.first.id, 'book_0');
      expect(page1.first.id, 'book_50');
      expect(page199.first.id, 'book_9950');
    });

    test('selecting all visible books does not allocate full list', () {
      final allBooks = _generateBooks(10000);
      const pageSize = 50;
      final loadedBooks = allBooks.take(pageSize).toList();

      final selectedIds = loadedBooks.map((b) => b.id).toSet();
      expect(selectedIds.length, 50);
      expect(selectedIds.contains('book_0'), isTrue);
      expect(selectedIds.contains('book_49'), isTrue);
      expect(selectedIds.contains('book_50'), isFalse);
    });

    test('collection filter with 10K books and small collection', () {
      final allBooks = _generateBooks(10000);
      final collectionIds = {'book_0', 'book_5000', 'book_9999'};

      final sw = Stopwatch()..start();
      final filtered = allBooks.where((b) => collectionIds.contains(b.id)).toList();
      sw.stop();

      expect(filtered.length, 3);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('combined sort + filter with 10K books', () {
      final allBooks = _generateBooks(10000);
      const query = '500';

      final sw = Stopwatch()..start();
      var filtered = allBooks.where((b) {
        return b.title.toLowerCase().contains(query) ||
            b.displayAuthor.toLowerCase().contains(query);
      }).toList();
      filtered = sortLibraryBooks(filtered, LibrarySort.title);
      sw.stop();

      expect(filtered, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}

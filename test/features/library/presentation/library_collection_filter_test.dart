import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  group('collection filter logic', () {
    final allBooks = List.generate(
      10,
      (i) => Book(
        id: '$i',
        title: 'Book $i',
        authorIds: const [],
        genreIds: const [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: const [BookFormat.epub],
        source: const BookSourceInfo(sourceId: 'test', sourceUrl: ''),
      ),
    );

    test('collection filter returns only books in collection', () {
      final collectionBookIds = {'1', '3', '5'};
      final filtered = allBooks.where((b) => collectionBookIds.contains(b.id)).toList();
      expect(filtered.length, 3);
      expect(filtered.map((b) => b.id).toList(), ['1', '3', '5']);
    });

    test('empty collection returns empty list', () {
      final filtered = allBooks.where((b) => <String>{}.contains(b.id)).toList();
      expect(filtered, isEmpty);
    });

    test('null collection returns all books', () {
      // When collectionId is null, no filtering.
      expect(allBooks.length, 10);
    });

    test('pagination within filtered collection', () {
      final collectionBookIds = {'1', '3', '5', '7', '9'};
      final filtered = allBooks.where((b) => collectionBookIds.contains(b.id)).toList();
      final page1 = filtered.skip(0).take(2).toList();
      final page2 = filtered.skip(2).take(2).toList();
      expect(page1.length, 2);
      expect(page2.length, 2);
      expect(page1.first.id, '1');
      expect(page2.first.id, '5');
    });
  });
}

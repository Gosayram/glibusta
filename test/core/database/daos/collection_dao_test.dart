import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('CollectionDao', () {
    test('insertCollection and getAllCollections', () async {
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c1', name: 'Favorites'),
      );
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c2', name: 'To Read'),
      );
      final all = await db.collectionDao.getAllCollections();
      expect(all.length, 2);
    });

    test('getCollectionById returns correct collection', () async {
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c1', name: 'Favorites'),
      );
      final col = await db.collectionDao.getCollectionById('c1');
      expect(col, isNotNull);
      expect(col!.name, 'Favorites');
    });

    test('getCollectionById returns null for missing', () async {
      final col = await db.collectionDao.getCollectionById('missing');
      expect(col, isNull);
    });

    test('deleteCollection removes collection', () async {
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c1', name: 'Favorites'),
      );
      await db.collectionDao.deleteCollection('c1');
      final col = await db.collectionDao.getCollectionById('c1');
      expect(col, isNull);
    });

    test('addBookToCollection and getBooksInCollection', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c1', name: 'Favorites'),
      );

      await db.collectionDao.addBookToCollection('b1', 'c1');
      await db.collectionDao.addBookToCollection('b2', 'c1');

      final books = await db.collectionDao.getBooksInCollection('c1');
      expect(books.length, 2);
    });

    test('removeBookFromCollection removes book', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c1', name: 'Favorites'),
      );
      await db.collectionDao.addBookToCollection('b1', 'c1');

      await db.collectionDao.removeBookFromCollection('b1', 'c1');
      final books = await db.collectionDao.getBooksInCollection('c1');
      expect(books, isEmpty);
    });

    test('getCollectionsForBook returns collections', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c1', name: 'Favorites'),
      );
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: 'c2', name: 'To Read'),
      );
      await db.collectionDao.addBookToCollection('b1', 'c1');
      await db.collectionDao.addBookToCollection('b1', 'c2');

      final cols = await db.collectionDao.getCollectionsForBook('b1');
      expect(cols.length, 2);
    });

    test('getCollectionsForBook returns empty for book with no collections', () async {
      final cols = await db.collectionDao.getCollectionsForBook('missing');
      expect(cols, isEmpty);
    });
  });
}

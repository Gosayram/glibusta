import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'collection_dao.g.dart';

@DriftAccessor(tables: [Collections, BookCollections, SavedBooks])
class CollectionDao extends DatabaseAccessor<AppDatabase> with _$CollectionDaoMixin {
  CollectionDao(super.attachedDatabase);

  Future<List<Collection>> getAllCollections() async => select(collections).get();

  Stream<List<Collection>> watchAllCollections() => select(collections).watch();

  Future<Collection?> getCollectionById(String id) async =>
      (select(collections)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCollection(CollectionsCompanion entry) =>
      into(collections).insertOnConflictUpdate(entry);

  Future<int> deleteCollection(String id) async {
    await (delete(bookCollections)..where((t) => t.collectionId.equals(id))).go();
    return (delete(collections)..where((t) => t.id.equals(id))).go();
  }

  Future<List<BookCollection>> getBookCollectionsForBook(String bookId) async =>
      (select(bookCollections)..where((t) => t.bookId.equals(bookId))).get();

  Future<List<Collection>> getCollectionsForBook(String bookId) async {
    final bcRows = await getBookCollectionsForBook(bookId);
    if (bcRows.isEmpty) return [];
    final colIds = bcRows.map((r) => r.collectionId).toList();
    return (select(collections)..where((t) => t.id.isIn(colIds))).get();
  }

  Future<void> addBookToCollection(String bookId, String collectionId) {
    return attachedDatabase.transaction(() async {
      await into(bookCollections).insertOnConflictUpdate(
        BookCollectionsCompanion.insert(
          bookId: bookId,
          collectionId: collectionId,
        ),
      );
      await _syncBookIds(collectionId);
    });
  }

  Future<void> removeBookFromCollection(String bookId, String collectionId) {
    return attachedDatabase.transaction(() async {
      await (delete(bookCollections)..where(
            (t) => t.bookId.equals(bookId) & t.collectionId.equals(collectionId),
          ))
          .go();
      await _syncBookIds(collectionId);
    });
  }

  // ponytail: denormalized cache kept in sync with join table; column already
  // exists and is used by export/import, so recompute after each mutation.
  Future<void> _syncBookIds(String collectionId) async {
    final rows = await (select(
      bookCollections,
    )..where((t) => t.collectionId.equals(collectionId))).get();
    final ids = rows.map((r) => r.bookId).toList();
    await (update(collections)..where((t) => t.id.equals(collectionId))).write(
      CollectionsCompanion(bookIds: Value(ids)),
    );
  }

  Future<List<SavedBook>> getBooksInCollection(String collectionId) async {
    final bcRows = await (select(
      bookCollections,
    )..where((t) => t.collectionId.equals(collectionId))).get();
    if (bcRows.isEmpty) return [];
    final bookIds = bcRows.map((r) => r.bookId).toList();
    return (select(savedBooks)..where((t) => t.id.isIn(bookIds))).get();
  }
}

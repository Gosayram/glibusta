import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'collection_dao.g.dart';

@DriftAccessor(tables: [Collections, BookCollections, SavedBooks])
class CollectionDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionDaoMixin {
  CollectionDao(super.db);

  Future<List<Collection>> getAllCollections() async => select(collections).get();

  Future<Collection?> getCollectionById(String id) async =>
      (select(collections)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCollection(CollectionsCompanion entry) =>
      into(collections).insertOnConflictUpdate(entry);

  Future<int> deleteCollection(String id) =>
      (delete(collections)..where((t) => t.id.equals(id))).go();

  Future<List<BookCollection>> getBookCollectionsForBook(String bookId) async =>
      (select(bookCollections)..where((t) => t.bookId.equals(bookId))).get();

  Future<List<Collection>> getCollectionsForBook(String bookId) async {
    final bcRows = await getBookCollectionsForBook(bookId);
    if (bcRows.isEmpty) return [];
    final colIds = bcRows.map((r) => r.collectionId).toList();
    return (select(collections)..where((t) => t.id.isIn(colIds))).get();
  }

  Future<void> addBookToCollection(String bookId, String collectionId) async {
    await into(bookCollections).insertOnConflictUpdate(
      BookCollectionsCompanion.insert(
        bookId: bookId,
        collectionId: collectionId,
      ),
    );
  }

  Future<void> removeBookFromCollection(
    String bookId,
    String collectionId,
  ) async {
    await (delete(bookCollections)
          ..where(
            (t) =>
                t.bookId.equals(bookId) &
                t.collectionId.equals(collectionId),
          ))
        .go();
  }

  Future<List<SavedBook>> getBooksInCollection(String collectionId) async {
    final bcRows = await (select(bookCollections)
          ..where((t) => t.collectionId.equals(collectionId)))
        .get();
    if (bcRows.isEmpty) return [];
    final bookIds = bcRows.map((r) => r.bookId).toList();
    return (select(savedBooks)..where((t) => t.id.isIn(bookIds))).get();
  }
}

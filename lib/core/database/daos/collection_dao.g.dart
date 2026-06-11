// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CollectionsTable get collections => attachedDatabase.collections;
  $BookCollectionsTable get bookCollections => attachedDatabase.bookCollections;
  $SavedBooksTable get savedBooks => attachedDatabase.savedBooks;
  CollectionDaoManager get managers => CollectionDaoManager(this);
}

class CollectionDaoManager {
  final _$CollectionDaoMixin _db;
  CollectionDaoManager(this._db);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
  $$BookCollectionsTableTableManager get bookCollections =>
      $$BookCollectionsTableTableManager(
        _db.attachedDatabase,
        _db.bookCollections,
      );
  $$SavedBooksTableTableManager get savedBooks =>
      $$SavedBooksTableTableManager(_db.attachedDatabase, _db.savedBooks);
}

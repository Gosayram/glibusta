// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_dao.dart';

// ignore_for_file: type=lint
mixin _$TagDaoMixin on DatabaseAccessor<AppDatabase> {
  $TagsTable get tags => attachedDatabase.tags;
  $BookTagsTable get bookTags => attachedDatabase.bookTags;
  $SavedBooksTable get savedBooks => attachedDatabase.savedBooks;
  TagDaoManager get managers => TagDaoManager(this);
}

class TagDaoManager {
  final _$TagDaoMixin _db;
  TagDaoManager(this._db);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$BookTagsTableTableManager get bookTags =>
      $$BookTagsTableTableManager(_db.attachedDatabase, _db.bookTags);
  $$SavedBooksTableTableManager get savedBooks =>
      $$SavedBooksTableTableManager(_db.attachedDatabase, _db.savedBooks);
}

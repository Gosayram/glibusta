// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'author_dao.dart';

// ignore_for_file: type=lint
mixin _$AuthorDaoMixin on DatabaseAccessor<AppDatabase> {
  $AuthorsTable get authors => attachedDatabase.authors;
  $SavedBooksTable get savedBooks => attachedDatabase.savedBooks;
  AuthorDaoManager get managers => AuthorDaoManager(this);
}

class AuthorDaoManager {
  final _$AuthorDaoMixin _db;
  AuthorDaoManager(this._db);
  $$AuthorsTableTableManager get authors =>
      $$AuthorsTableTableManager(_db.attachedDatabase, _db.authors);
  $$SavedBooksTableTableManager get savedBooks =>
      $$SavedBooksTableTableManager(_db.attachedDatabase, _db.savedBooks);
}

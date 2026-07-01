// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_dao.dart';

// ignore_for_file: type=lint
mixin _$BookDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedBooksTable get savedBooks => attachedDatabase.savedBooks;
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  $ReadingSessionsTable get readingSessions => attachedDatabase.readingSessions;
  BookDaoManager get managers => BookDaoManager(this);
}

class BookDaoManager {
  final _$BookDaoMixin _db;
  BookDaoManager(this._db);
  $$SavedBooksTableTableManager get savedBooks =>
      $$SavedBooksTableTableManager(_db.attachedDatabase, _db.savedBooks);
  $$ReadingProgressTableTableManager get readingProgress => $$ReadingProgressTableTableManager(
    _db.attachedDatabase,
    _db.readingProgress,
  );
  $$ReadingSessionsTableTableManager get readingSessions => $$ReadingSessionsTableTableManager(
    _db.attachedDatabase,
    _db.readingSessions,
  );
}

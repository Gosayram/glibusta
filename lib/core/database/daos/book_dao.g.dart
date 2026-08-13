// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_dao.dart';

// ignore_for_file: type=lint
mixin _$BookDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedBooksTable get savedBooks => attachedDatabase.savedBooks;
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  $ReadingSessionsTable get readingSessions => attachedDatabase.readingSessions;
  $BookmarksTable get bookmarks => attachedDatabase.bookmarks;
  $NotesTable get notes => attachedDatabase.notes;
  $QuotesTable get quotes => attachedDatabase.quotes;
  $TextHighlightsTable get textHighlights => attachedDatabase.textHighlights;
  $ReadingTimeTable get readingTime => attachedDatabase.readingTime;
  $BookCollectionsTable get bookCollections => attachedDatabase.bookCollections;
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
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db.attachedDatabase, _db.bookmarks);
  $$NotesTableTableManager get notes => $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
  $$QuotesTableTableManager get quotes =>
      $$QuotesTableTableManager(_db.attachedDatabase, _db.quotes);
  $$TextHighlightsTableTableManager get textHighlights => $$TextHighlightsTableTableManager(
    _db.attachedDatabase,
    _db.textHighlights,
  );
  $$ReadingTimeTableTableManager get readingTime =>
      $$ReadingTimeTableTableManager(_db.attachedDatabase, _db.readingTime);
  $$BookCollectionsTableTableManager get bookCollections => $$BookCollectionsTableTableManager(
    _db.attachedDatabase,
    _db.bookCollections,
  );
}

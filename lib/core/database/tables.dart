import 'package:drift/drift.dart';

import 'converters.dart';

@TableIndex(name: 'idx_saved_books_content_hash', columns: {#contentHash})
class SavedBooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authorIds =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get genreIds =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get coverStatus => text().withDefault(const Constant('none'))();
  DateTimeColumn get publishDate => dateTime().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime().clientDefault(DateTime.now)();
  TextColumn get contentHash => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get filePath => text().withDefault(const Constant(''))();
  TextColumn get readingStatus => text().withDefault(const Constant('none'))();
  TextColumn get detectedEncoding => text().nullable()();
  RealColumn get encodingConfidence => real().nullable()();
  TextColumn get encodingSource => text().nullable()();
  TextColumn get userForcedEncoding => text().nullable()();
  TextColumn get storageMode => text().withDefault(const Constant('internal'))();
  TextColumn get externalUri => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Authors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bookIds =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Series extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get bookIds =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BookSeries extends Table {
  TextColumn get bookId => text()();
  TextColumn get seriesId => text()();
  IntColumn get sequenceNumber => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {bookId, seriesId};
}

class Genres extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_downloads_bookId', columns: {#bookId})
class Downloads extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get bookTitle => text().withDefault(const Constant(''))();
  TextColumn get format => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get targetPath => text().nullable()();
  IntColumn get status => intEnum<DownloadStatusDb>()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

enum DownloadStatusDb { queued, running, paused, completed, failed, canceled }

class ReadingProgress extends Table {
  TextColumn get bookId => text()();
  IntColumn get currentPosition => integer().withDefault(const Constant(0))();
  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();
  IntColumn get paragraphIndex => integer().withDefault(const Constant(0))();
  RealColumn get localOffset => real().withDefault(const Constant(0.0))();
  RealColumn get progressPercent => real().withDefault(const Constant(0.0))();
  IntColumn get totalPages => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRead => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

@TableIndex(name: 'idx_bookmarks_bookId', columns: {#bookId})
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get paragraphIndex => integer()();
  RealColumn get localOffset => real().withDefault(const Constant(0.0))();
  TextColumn get selectedText => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_notes_bookId', columns: {#bookId})
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get paragraphIndex => integer()();
  RealColumn get localOffset => real().withDefault(const Constant(0.0))();
  TextColumn get content => text()();
  TextColumn get highlightColor => text().withDefault(const Constant('#FFEB3B'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_quotes_bookId', columns: {#bookId})
class Quotes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get paragraphIndex => integer()();
  TextColumn get selectedText => text()();
  TextColumn get beforeContext => text().nullable()();
  TextColumn get afterContext => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  TextColumn get type => text()(); // 'online', 'local', 'reader'
  DateTimeColumn get searchedAt => dateTime().clientDefault(DateTime.now)();
}

class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get bookIds =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_book_collections_collection_id', columns: {#collectionId})
class BookCollections extends Table {
  TextColumn get bookId => text()();
  TextColumn get collectionId => text()();
  DateTimeColumn get addedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId, collectionId};
}

@TableIndex(name: 'idx_reading_sessions_bookId', columns: {#bookId})
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  DateTimeColumn get startedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get chaptersRead => integer().withDefault(const Constant(0))();
}

class PerBookSettings extends Table {
  TextColumn get bookId => text()();
  TextColumn get settingsJson => text()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#2196F3'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_book_tags_tag_id', columns: {#tagId})
class BookTags extends Table {
  TextColumn get bookId => text()();
  TextColumn get tagId => text()();
  DateTimeColumn get addedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId, tagId};
}

class ReadingTime extends Table {
  TextColumn get bookId => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get readingTimeSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId, date};
}

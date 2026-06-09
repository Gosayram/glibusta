import 'package:drift/drift.dart';

class SavedBooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authorIds => text().withDefault(const Constant('[]'))();
  TextColumn get genreIds => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  DateTimeColumn get publishDate => dateTime().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Authors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bookIds => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Series extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get bookIds => text().withDefault(const Constant('[]'))();

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
  IntColumn get totalPages => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRead => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

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
  TextColumn get bookIds => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BookCollections extends Table {
  TextColumn get bookId => text()();
  TextColumn get collectionId => text()();
  DateTimeColumn get addedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {bookId, collectionId};
}

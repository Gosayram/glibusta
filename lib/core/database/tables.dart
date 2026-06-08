import 'package:drift/drift.dart';

class SavedBooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authorIds => text().withDefault(const Constant('[]'))();
  TextColumn get genreIds => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  DateTimeColumn get publishDate => dateTime().nullable()();
  TextColumn get sourceId => text().withDefault(const Constant('flibusta'))();
  TextColumn get sourceUrl => text().withDefault(const Constant(''))();
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

import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authorIds => text().nullable()();
  TextColumn get genreIds => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  DateTimeColumn get publishDate => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Authors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bookIds => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Genres extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Downloads extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get format => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get targetPath => text().nullable()();
  IntColumn get status => integer()();
  IntColumn get downloadedBytes => integer().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ReadingProgress extends Table {
  TextColumn get bookId => text()();
  IntColumn get currentPosition => integer()();
  DateTimeColumn get lastRead => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>>? get primaryKey => {bookId};
}
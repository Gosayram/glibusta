import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SavedBooks,
    Authors,
    Series,
    BookSeries,
    Genres,
    Downloads,
    ReadingProgress,
    Bookmarks,
    Notes,
    Quotes,
    SearchHistory,
    Collections,
    BookCollections,
    ReadingSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(savedBooks, savedBooks.contentHash);
        await m.addColumn(savedBooks, savedBooks.fileSize);
      }
      if (from < 3) {
        await m.addColumn(savedBooks, savedBooks.filePath);
      }
      if (from < 4) {
        await m.createTable(readingSessions);
      }
      if (from < 5) {
        await m.addColumn(readingProgress, readingProgress.chapterIndex);
        await m.addColumn(readingProgress, readingProgress.paragraphIndex);
        await m.addColumn(readingProgress, readingProgress.localOffset);
        await m.addColumn(readingProgress, readingProgress.progressPercent);
        await m.addColumn(readingProgress, readingProgress.updatedAt);
      }
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        await _backupDatabase(details.versionBefore);
      }
    },
  );

  Future<void> _backupDatabase(int? previousVersion) async {
    try {
      final dbFile = File(await _databasePath);
      if (await dbFile.exists()) {
        final backupFile = File('${await _databasePath}.v${previousVersion ?? 0}.bak');
        await dbFile.copy(backupFile.path);
      }
    } on Object catch (_) {}
  }

  static Future<String> get _databasePath async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'glibusta', 'glibusta.db');
  }

  // --- SavedBooks ---
  Future<List<SavedBook>> getAllBooks() async {
    return select(savedBooks).get();
  }

  Future<SavedBook?> getBookById(String id) async {
    return (select(savedBooks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertBook(SavedBooksCompanion entry) {
    return into(savedBooks).insertOnConflictUpdate(entry);
  }

  Future<int> deleteBook(String id) {
    return (delete(savedBooks)..where((t) => t.id.equals(id))).go();
  }

  // --- Authors ---
  Future<List<Author>> getAllAuthors() async {
    return select(authors).get();
  }

  Future<int> insertAuthor(AuthorsCompanion entry) {
    return into(authors).insertOnConflictUpdate(entry);
  }

  // --- Genres ---
  Future<List<Genre>> getAllGenres() async {
    return select(genres).get();
  }

  Future<int> insertGenre(GenresCompanion entry) {
    return into(genres).insertOnConflictUpdate(entry);
  }

  // --- Downloads ---
  Future<List<Download>> getAllDownloads() async {
    return (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Stream<List<Download>> watchAllDownloads() {
    return (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<Download?> getDownloadById(String id) async {
    return (select(downloads)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertDownload(DownloadsCompanion entry) {
    return into(downloads).insertOnConflictUpdate(entry);
  }

  Future<int> updateDownloadStatus(String id, DownloadStatusDb status) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(status: Value(status)),
    );
  }

  Future<int> updateDownloadProgress(String id, int downloaded, int total) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(
        downloadedBytes: Value(downloaded),
        totalBytes: Value(total),
      ),
    );
  }

  Future<int> deleteDownload(String id) {
    return (delete(downloads)..where((t) => t.id.equals(id))).go();
  }

  // --- Reading Progress ---
  Future<ReadingProgressData?> getReadingProgress(String bookId) async {
    return (select(readingProgress)..where((t) => t.bookId.equals(bookId))).getSingleOrNull();
  }

  Future<int> upsertReadingProgress(ReadingProgressCompanion entry) {
    return into(readingProgress).insertOnConflictUpdate(entry);
  }

  Future<int> deleteReadingProgress(String bookId) {
    return (delete(readingProgress)..where((t) => t.bookId.equals(bookId))).go();
  }

  Future<List<SavedBook>> getBooksWithProgress() async {
    final query = select(savedBooks).join([
      innerJoin(
        readingProgress,
        readingProgress.bookId.equalsExp(savedBooks.id),
      ),
    ]);
    query.orderBy([OrderingTerm.desc(readingProgress.lastRead)]);
    final rows = await query.get();
    return rows.map((row) => row.readTable(savedBooks)).toList();
  }

  Stream<List<SavedBook>> watchBooksWithProgress() {
    final query = select(savedBooks).join([
      innerJoin(
        readingProgress,
        readingProgress.bookId.equalsExp(savedBooks.id),
      ),
    ]);
    query.orderBy([OrderingTerm.desc(readingProgress.lastRead)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(savedBooks)).toList(),
    );
  }

  // --- Reading Sessions ---
  Future<int> startSession(String bookId) {
    return into(readingSessions).insert(
      ReadingSessionsCompanion.insert(bookId: bookId),
    );
  }

  Future<void> endSession(int sessionId, {int chaptersRead = 0}) {
    return (update(readingSessions)..where((t) => t.id.equals(sessionId))).write(
      ReadingSessionsCompanion(
        endedAt: Value(DateTime.now()),
        chaptersRead: Value(chaptersRead),
      ),
    );
  }

  Future<List<ReadingSession>> getSessionsForDateRange(DateTime start, DateTime end) {
    return (select(readingSessions)
          ..where((t) => t.startedAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<Map<DateTime, int>> getDailyReadingMinutes(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    final sessions = await getSessionsForDateRange(start, now);
    final dailyMinutes = <DateTime, int>{};

    for (final session in sessions) {
      final day = DateTime(session.startedAt.year, session.startedAt.month, session.startedAt.day);
      final end = session.endedAt ?? DateTime.now();
      final minutes = end.difference(session.startedAt).inMinutes;
      dailyMinutes[day] = (dailyMinutes[day] ?? 0) + minutes;
    }

    return dailyMinutes;
  }

  // --- Bookmarks ---
  Future<List<Bookmark>> getBookmarksForBook(String bookId) {
    return (select(bookmarks)..where((t) => t.bookId.equals(bookId))).get();
  }

  // --- Quotes ---
  Future<List<Quote>> getQuotesForBook(String bookId) {
    return (select(quotes)..where((t) => t.bookId.equals(bookId))).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'glibusta', 'glibusta.db'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

import 'dart:convert';
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
  int get schemaVersion => 6;

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
      if (from < 6) {
        await m.addColumn(savedBooks, savedBooks.readingStatus);
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

  Future<int> updateReadingStatus(String bookId, String status) {
    return (update(savedBooks)..where((t) => t.id.equals(bookId))).write(
      SavedBooksCompanion(readingStatus: Value(status)),
    );
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

  // --- Authors (resolve) ---
  Future<Map<String, String>> getAuthorNamesByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final query = select(authors)..where((t) => t.id.isIn(ids));
    final rows = await query.get();
    return {for (final row in rows) row.id: row.name};
  }

  Future<List<Author>> getAuthorsForBook(String bookId) async {
    final book = await getBookById(bookId);
    if (book == null) return [];
    final ids = book.authorIds.isNotEmpty
        ? List<String>.from(jsonDecode(book.authorIds) as List<dynamic>)
        : <String>[];
    if (ids.isEmpty) return [];
    return (select(authors)..where((t) => t.id.isIn(ids))).get();
  }

  // --- Series ---
  Future<List<Sery>> getAllSeries() async {
    return select(series).get();
  }

  Future<Sery?> getSeriesById(String id) async {
    return (select(series)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertSeries(SeriesCompanion entry) {
    return into(series).insertOnConflictUpdate(entry);
  }

  Future<List<BookSery>> getBookSeriesForBook(String bookId) async {
    return (select(bookSeries)..where((t) => t.bookId.equals(bookId))).get();
  }

  Future<List<Sery>> getSeriesForBook(String bookId) async {
    final bsRows = await getBookSeriesForBook(bookId);
    if (bsRows.isEmpty) return [];
    final seriesIds = bsRows.map((r) => r.seriesId).toList();
    return (select(series)..where((t) => t.id.isIn(seriesIds))).get();
  }

  Future<List<BookSery>> getBooksInSeries(String seriesId) async {
    return (select(bookSeries)..where((t) => t.seriesId.equals(seriesId))).get();
  }

  // --- Collections ---
  Future<List<Collection>> getAllCollections() async {
    return select(collections).get();
  }

  Future<Collection?> getCollectionById(String id) async {
    return (select(collections)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCollection(CollectionsCompanion entry) {
    return into(collections).insertOnConflictUpdate(entry);
  }

  Future<int> deleteCollection(String id) async {
    return (delete(collections)..where((t) => t.id.equals(id))).go();
  }

  Future<List<BookCollection>> getBookCollectionsForBook(String bookId) async {
    return (select(bookCollections)..where((t) => t.bookId.equals(bookId))).get();
  }

  Future<List<Collection>> getCollectionsForBook(String bookId) async {
    final bcRows = await getBookCollectionsForBook(bookId);
    if (bcRows.isEmpty) return [];
    final colIds = bcRows.map((r) => r.collectionId).toList();
    return (select(collections)..where((t) => t.id.isIn(colIds))).get();
  }

  Future<void> addBookToCollection(String bookId, String collectionId) async {
    await into(bookCollections).insertOnConflictUpdate(
      BookCollectionsCompanion.insert(bookId: bookId, collectionId: collectionId),
    );
  }

  Future<void> removeBookFromCollection(String bookId, String collectionId) async {
    await (delete(
      bookCollections,
    )..where((t) => t.bookId.equals(bookId) & t.collectionId.equals(collectionId))).go();
  }

  Future<List<SavedBook>> getBooksInCollection(String collectionId) async {
    final bcRows = await (select(
      bookCollections,
    )..where((t) => t.collectionId.equals(collectionId))).get();
    if (bcRows.isEmpty) return [];
    final bookIds = bcRows.map((r) => r.bookId).toList();
    return (select(savedBooks)..where((t) => t.id.isIn(bookIds))).get();
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

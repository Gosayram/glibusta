import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'book_dao.g.dart';

@DriftAccessor(tables: [SavedBooks, ReadingProgress, ReadingSessions])
class BookDao extends DatabaseAccessor<AppDatabase> with _$BookDaoMixin {
  BookDao(super.attachedDatabase);

  Future<List<SavedBook>> getAllBooks() async => select(savedBooks).get();

  Future<SavedBook?> getBookById(String id) async =>
      (select(savedBooks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertBook(SavedBooksCompanion entry) =>
      into(savedBooks).insertOnConflictUpdate(entry);

  Future<int> deleteBook(String id) => (delete(savedBooks)..where((t) => t.id.equals(id))).go();

  Future<int> updateReadingStatus(String bookId, String status) =>
      (update(savedBooks)..where((t) => t.id.equals(bookId))).write(
        SavedBooksCompanion(readingStatus: Value(status)),
      );

  Future<ReadingProgressData?> getReadingProgress(String bookId) async =>
      (select(readingProgress)..where((t) => t.bookId.equals(bookId))).getSingleOrNull();

  Future<int> upsertReadingProgress(ReadingProgressCompanion entry) =>
      into(readingProgress).insertOnConflictUpdate(entry);

  Future<int> deleteReadingProgress(String bookId) =>
      (delete(readingProgress)..where((t) => t.bookId.equals(bookId))).go();

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

  Future<int> startSession(String bookId) =>
      into(readingSessions).insert(ReadingSessionsCompanion.insert(bookId: bookId));

  Future<void> endSession(int sessionId, {int chaptersRead = 0}) =>
      (update(readingSessions)..where((t) => t.id.equals(sessionId))).write(
        ReadingSessionsCompanion(
          endedAt: Value(DateTime.now()),
          chaptersRead: Value(chaptersRead),
        ),
      );

  Future<List<ReadingSession>> getSessionsForDateRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(readingSessions)
            ..where((t) => t.startedAt.isBetweenValues(start, end))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  Future<Map<DateTime, int>> getDailyReadingMinutes(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    final sessions = await getSessionsForDateRange(start, now);
    final dailyMinutes = <DateTime, int>{};

    for (final session in sessions) {
      final day = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      final end = session.endedAt ?? DateTime.now();
      final minutes = end.difference(session.startedAt).inMinutes;
      dailyMinutes[day] = (dailyMinutes[day] ?? 0) + minutes;
    }

    return dailyMinutes;
  }
}

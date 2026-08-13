import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'book_dao.g.dart';

@DriftAccessor(tables: [SavedBooks, ReadingProgress, ReadingSessions])
class BookDao extends DatabaseAccessor<AppDatabase> with _$BookDaoMixin {
  BookDao(super.attachedDatabase);

  Future<List<SavedBook>> getAllBooks() async =>
      (select(savedBooks)..where((t) => t.deletedAt.isNull())).get();

  Future<List<SavedBook>> getPagedBooks({
    required int limit,
    int offset = 0,
    List<OrderingTerm Function($SavedBooksTable t)>? orderBy,
    String? formatFilter,
    List<String>? bookIds,
  }) async {
    final query = select(savedBooks)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            (formatFilter != null ? t.filePath.like('%.$formatFilter') : const Constant(true)) &
            (bookIds != null ? t.id.isIn(bookIds) : const Constant(true)),
      )
      ..limit(limit, offset: offset);
    if (orderBy != null) {
      query.orderBy(orderBy);
    } else {
      query.orderBy([(t) => OrderingTerm.desc(t.addedAt)]);
    }
    return query.get();
  }

  Future<List<SavedBook>> searchBooks(String query) async {
    final lower = '%$query%';
    return (select(savedBooks)
          ..where(
            (t) =>
                (t.title.like(lower) | t.description.like(lower)) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
  }

  Future<List<SavedBook>> searchBooksPaged(
    String query, {
    required int limit,
    int offset = 0,
    String? formatFilter,
  }) async {
    final lower = '%$query%';
    return (select(savedBooks)
          ..where(
            (t) =>
                (t.title.like(lower) | t.description.like(lower)) &
                t.deletedAt.isNull() &
                (formatFilter != null ? t.filePath.like('%.$formatFilter') : const Constant(true)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.title)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<SavedBook?> getBookById(String id) async =>
      (select(savedBooks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<SavedBook?> watchBookById(String bookId) {
    return (select(savedBooks)..where((t) => t.id.equals(bookId))).watchSingleOrNull();
  }

  Future<List<SavedBook>> getBooksByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return (select(savedBooks)..where((t) => t.id.isIn(ids))).get();
  }

  Future<List<ReadingProgressData>> getAllReadingProgress() async => select(readingProgress).get();

  Future<int> insertBook(SavedBooksCompanion entry) =>
      into(savedBooks).insertOnConflictUpdate(entry);

  Future<int> deleteBook(String id) => (delete(savedBooks)..where((t) => t.id.equals(id))).go();

  Future<int> softDeleteBook(String id) =>
      (update(savedBooks)..where((t) => t.id.equals(id))).write(
        SavedBooksCompanion(deletedAt: Value(DateTime.now())),
      );

  Future<int> restoreBook(String id) => (update(savedBooks)..where((t) => t.id.equals(id))).write(
    const SavedBooksCompanion(deletedAt: Value(null)),
  );

  Future<List<SavedBook>> getDeletedBooks() =>
      (select(savedBooks)..where((t) => t.deletedAt.isNotNull())).get();

  Future<int> purgeDeletedBooks() =>
      (delete(savedBooks)..where((t) => t.deletedAt.isNotNull())).go();

  Future<int> updateReadingStatus(String bookId, String status) =>
      (update(savedBooks)..where((t) => t.id.equals(bookId))).write(
        SavedBooksCompanion(readingStatus: Value(status)),
      );

  Future<int> updateBook({
    required String bookId,
    String? title,
    List<String>? authorIds,
    String? description,
  }) {
    final companion = SavedBooksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      authorIds: authorIds != null ? Value(authorIds) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
    );
    return (update(savedBooks)..where((t) => t.id.equals(bookId))).write(companion);
  }

  Future<ReadingProgressData?> getReadingProgress(String bookId) async =>
      (select(readingProgress)..where((t) => t.bookId.equals(bookId))).getSingleOrNull();

  Future<int> upsertReadingProgress(ReadingProgressCompanion entry) =>
      into(readingProgress).insertOnConflictUpdate(entry);

  Future<int> deleteReadingProgress(String bookId) =>
      (delete(readingProgress)..where((t) => t.bookId.equals(bookId))).go();

  Future<List<SavedBook>> getPagedBooksWithProgress({
    required int limit,
    int offset = 0,
    bool ascending = true,
    String? formatFilter,
    List<String>? bookIds,
  }) async {
    final direction = ascending ? OrderingMode.asc : OrderingMode.desc;
    final query =
        select(savedBooks).join([
            leftOuterJoin(readingProgress, readingProgress.bookId.equalsExp(savedBooks.id)),
          ])
          ..where(
            savedBooks.deletedAt.isNull() &
                (formatFilter != null
                    ? savedBooks.filePath.like('%.$formatFilter')
                    : const Constant(true)) &
                (bookIds != null ? savedBooks.id.isIn(bookIds) : const Constant(true)),
          )
          ..orderBy([OrderingTerm(expression: readingProgress.progressPercent, mode: direction)])
          ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map((row) => row.readTable(savedBooks)).toList();
  }

  Future<List<SavedBook>> getBooksWithProgress() async {
    final query = select(savedBooks).join([
      innerJoin(
        readingProgress,
        readingProgress.bookId.equalsExp(savedBooks.id),
      ),
    ]);
    query.where(savedBooks.deletedAt.isNull());
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
    query.where(savedBooks.deletedAt.isNull());
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

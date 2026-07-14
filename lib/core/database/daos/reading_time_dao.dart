import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';
import '../tables.dart';

part 'reading_time_dao.g.dart';

@DriftAccessor(tables: [ReadingTime])
class ReadingTimeDao extends DatabaseAccessor<AppDatabase> with _$ReadingTimeDaoMixin {
  ReadingTimeDao(super.attachedDatabase);

  Future<void> addReadingTime(String bookId, DateTime date, int seconds) async {
    final day = DateTime(date.year, date.month, date.day);
    await transaction(() async {
      final existing = await (select(
        readingTime,
      )..where((t) => t.bookId.equals(bookId) & t.date.equals(day))).getSingleOrNull();

      if (existing != null) {
        await (update(
          readingTime,
        )..where((t) => t.bookId.equals(bookId) & t.date.equals(day))).write(
          ReadingTimeCompanion(
            readingTimeSeconds: Value(existing.readingTimeSeconds + seconds),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await into(readingTime).insert(
          ReadingTimeCompanion.insert(
            bookId: bookId,
            date: day,
            readingTimeSeconds: Value(seconds),
          ),
        );
      }
    });
  }

  Future<int> getTotalReadingSeconds(String bookId) async {
    final query = readingTime.readingTimeSeconds;
    final result =
        await (selectOnly(readingTime)
              ..addColumns([query.sum()])
              ..where(readingTime.bookId.equals(bookId)))
            .getSingle();
    return result.read(query.sum()) ?? 0;
  }

  Future<int> getDailyReadingSeconds(String bookId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final result = await (select(
      readingTime,
    )..where((t) => t.bookId.equals(bookId) & t.date.equals(day))).getSingleOrNull();
    return result?.readingTimeSeconds ?? 0;
  }

  Future<Map<DateTime, int>> getReadingTimeByDay(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    final results =
        await (select(readingTime)
              ..where((t) => t.date.isBiggerOrEqualValue(start))
              ..orderBy([(t) => OrderingTerm.asc(t.date)]))
            .get();

    final dailySeconds = <DateTime, int>{};
    for (final row in results) {
      final day = DateTime(row.date.year, row.date.month, row.date.day);
      dailySeconds[day] = (dailySeconds[day] ?? 0) + row.readingTimeSeconds;
    }

    return dailySeconds;
  }

  Stream<List<ReadingTimeRow>> watchAll() {
    final query = readingTime.readingTimeSeconds;
    return (selectOnly(readingTime)
          ..addColumns([readingTime.bookId, query.sum()])
          ..groupBy([readingTime.bookId])
          ..orderBy([OrderingTerm.desc(query.sum())]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => ReadingTimeRow(
                  bookId: row.read(readingTime.bookId)!,
                  totalSeconds: row.read(query.sum()) ?? 0,
                ),
              )
              .toList(),
        );
  }

  /// Returns total seconds grouped by hour of day (0-23) for recent readings.
  Future<Map<int, int>> getReadingHours(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final results = await (select(
      readingTime,
    )..where((t) => t.date.isBiggerOrEqualValue(start))).get();

    final hourlySeconds = <int, int>{};
    for (final row in results) {
      final hour = row.updatedAt.hour;
      hourlySeconds[hour] = (hourlySeconds[hour] ?? 0) + row.readingTimeSeconds;
    }
    return hourlySeconds;
  }

  Future<List<ReadingTimeRow>> getTopBooksByReadingTime({int limit = 10}) async {
    final query = readingTime.readingTimeSeconds;
    final results =
        await (selectOnly(readingTime)
              ..addColumns([readingTime.bookId, query.sum()])
              ..groupBy([readingTime.bookId])
              ..orderBy([OrderingTerm.desc(query.sum())])
              ..limit(limit))
            .get();

    return results.map((row) {
      return ReadingTimeRow(
        bookId: row.read(readingTime.bookId)!,
        totalSeconds: row.read(query.sum()) ?? 0,
      );
    }).toList();
  }
}

class ReadingTimeRow {
  const ReadingTimeRow({required this.bookId, required this.totalSeconds});

  final String bookId;
  final int totalSeconds;
}

final readingTimeDaoProvider = Provider<ReadingTimeDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.readingTimeDao;
});

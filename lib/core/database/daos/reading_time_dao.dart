import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';
import '../tables.dart';

part 'reading_time_dao.g.dart';

@DriftAccessor(tables: [ReadingTime])
class ReadingTimeDao extends DatabaseAccessor<AppDatabase> with _$ReadingTimeDaoMixin {
  ReadingTimeDao(super.attachedDatabase);

  Future<void> addReadingTime(String bookId, DateTime date, int seconds) async {
    if (seconds <= 0) return;
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

  Future<void> addPagesRead(String bookId, DateTime date, int pages) async {
    if (pages <= 0) return;
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
            pagesRead: Value(existing.pagesRead + pages),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await into(readingTime).insert(
          ReadingTimeCompanion.insert(
            bookId: bookId,
            date: day,
            pagesRead: Value(pages),
          ),
        );
      }
    });
  }

  Future<void> addWpm(String bookId, DateTime date, double wpm) async {
    if (wpm <= 0) return;
    final day = DateTime(date.year, date.month, date.day);
    await transaction(() async {
      final existing = await (select(
        readingTime,
      )..where((t) => t.bookId.equals(bookId) & t.date.equals(day))).getSingleOrNull();

      if (existing != null) {
        final count = existing.wpmSessionCount;
        final newAvg = (existing.wpm * count + wpm) / (count + 1);
        await (update(
          readingTime,
        )..where((t) => t.bookId.equals(bookId) & t.date.equals(day))).write(
          ReadingTimeCompanion(
            wpm: Value(newAvg),
            wpmSessionCount: Value(count + 1),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await into(readingTime).insert(
          ReadingTimeCompanion.insert(
            bookId: bookId,
            date: day,
            wpm: Value(wpm),
            wpmSessionCount: const Value(1),
          ),
        );
      }
    });
  }

  Future<double> getAverageWpmLast7Days() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final results = await (select(
      readingTime,
    )..where((t) => t.date.isBiggerOrEqualValue(start) & t.wpm.isBiggerThanValue(0))).get();
    if (results.isEmpty) return 0;
    var totalWpm = 0.0;
    var totalSessions = 0;
    for (final row in results) {
      totalWpm += row.wpm * row.wpmSessionCount;
      totalSessions += row.wpmSessionCount;
    }
    return totalSessions > 0 ? totalWpm / totalSessions : 0;
  }

  Future<Map<DateTime, double>> getDailyWpmLast7Days() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final results = await (select(
      readingTime,
    )..where((t) => t.date.isBiggerOrEqualValue(start) & t.wpm.isBiggerThanValue(0))).get();
    final dailyWpm = <DateTime, double>{};
    final dailyCounts = <DateTime, int>{};
    for (final row in results) {
      final day = DateTime(row.date.year, row.date.month, row.date.day);
      final prevWpm = dailyWpm[day];
      final prevCount = dailyCounts[day] ?? 0;
      final newCount = prevCount + row.wpmSessionCount;
      if (newCount > 0) {
        dailyWpm[day] = prevWpm == null
            ? row.wpm
            : (prevWpm * prevCount + row.wpm * row.wpmSessionCount) / newCount;
      }
      dailyCounts[day] = newCount;
    }
    return dailyWpm;
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

  Future<int> getTodayPages() async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final results = await (select(
      readingTime,
    )..where((t) => t.date.equals(day))).get();
    var total = 0;
    for (final row in results) {
      total += row.pagesRead;
    }
    return total;
  }

  Future<Map<DateTime, int>> getDailyPages(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final results = await (select(
      readingTime,
    )..where((t) => t.date.isBiggerOrEqualValue(start))).get();
    final dailyPages = <DateTime, int>{};
    for (final row in results) {
      final day = DateTime(row.date.year, row.date.month, row.date.day);
      dailyPages[day] = (dailyPages[day] ?? 0) + row.pagesRead;
    }
    return dailyPages;
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

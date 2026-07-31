import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('addPagesRead increments daily counter', () async {
    final now = DateTime(2026, 7, 31, 14);
    await database.readingTimeDao.addPagesRead('book1', now, 5);
    await database.readingTimeDao.addPagesRead('book1', now, 3);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 8);
  });

  test('addPagesRead with zero or negative is no-op', () async {
    final now = DateTime(2026, 7, 31, 14);
    await database.readingTimeDao.addPagesRead('book1', now, 0);
    await database.readingTimeDao.addPagesRead('book1', now, -1);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 0);
  });

  test('pages are aggregated across books for the same day', () async {
    final now = DateTime(2026, 7, 31, 14);
    await database.readingTimeDao.addPagesRead('book1', now, 5);
    await database.readingTimeDao.addPagesRead('book2', now, 7);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 12);
  });

  test('getTodayPages returns 0 when no data', () async {
    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 0);
  });

  test('getDailyPages returns per-day totals', () async {
    final today = DateTime(2026, 7, 31, 14);
    final yesterday = DateTime(2026, 7, 30, 10);
    await database.readingTimeDao.addPagesRead('book1', today, 10);
    await database.readingTimeDao.addPagesRead('book1', yesterday, 4);
    await database.readingTimeDao.addPagesRead('book2', yesterday, 6);

    final daily = await database.readingTimeDao.getDailyPages(7);

    final todayKey = DateTime(2026, 7, 31);
    final yesterdayKey = DateTime(2026, 7, 30);
    expect(daily[todayKey], 10);
    expect(daily[yesterdayKey], 10);
  });

  test('pages reset on a new day naturally via date key', () async {
    final day1 = DateTime(2026, 7, 30, 23);
    final day2 = DateTime(2026, 7, 31, 1);
    await database.readingTimeDao.addPagesRead('book1', day1, 15);

    final pagesDay1 = await database.readingTimeDao.getTodayPages();
    expect(pagesDay1, 0);

    await database.readingTimeDao.addPagesRead('book1', day2, 8);
    final pagesDay2 = await database.readingTimeDao.getTodayPages();
    expect(pagesDay2, 8);
  });

  test('concurrent addPagesRead increments are not lost', () async {
    final now = DateTime(2026, 7, 31, 14);
    await database.readingTimeDao.addPagesRead('book1', now, 1);

    await Future.wait([
      database.readingTimeDao.addPagesRead('book1', now, 2),
      database.readingTimeDao.addPagesRead('book1', now, 3),
    ]);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 6);
  });
}

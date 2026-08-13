import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 14);
  }

  DateTime yesterday() => today().subtract(const Duration(days: 1));

  test('addPagesRead increments daily counter', () async {
    await database.readingTimeDao.addPagesRead('book1', today(), 5);
    await database.readingTimeDao.addPagesRead('book1', today(), 3);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 8);
  });

  test('addPagesRead with zero or negative is no-op', () async {
    await database.readingTimeDao.addPagesRead('book1', today(), 0);
    await database.readingTimeDao.addPagesRead('book1', today(), -1);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 0);
  });

  test('pages are aggregated across books for the same day', () async {
    await database.readingTimeDao.addPagesRead('book1', today(), 5);
    await database.readingTimeDao.addPagesRead('book2', today(), 7);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 12);
  });

  test('getTodayPages returns 0 when no data', () async {
    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 0);
  });

  test('getDailyPages returns per-day totals', () async {
    await database.readingTimeDao.addPagesRead('book1', today(), 10);
    await database.readingTimeDao.addPagesRead('book1', yesterday(), 4);
    await database.readingTimeDao.addPagesRead('book2', yesterday(), 6);

    final daily = await database.readingTimeDao.getDailyPages(7);

    final todayKey = DateTime(today().year, today().month, today().day);
    final yesterdayKey = DateTime(yesterday().year, yesterday().month, yesterday().day);
    expect(daily[todayKey], 10);
    expect(daily[yesterdayKey], 10);
  });

  test('pages reset on a new day naturally via date key', () async {
    await database.readingTimeDao.addPagesRead('book1', yesterday(), 15);

    final pagesToday = await database.readingTimeDao.getTodayPages();
    expect(pagesToday, 0);

    await database.readingTimeDao.addPagesRead('book1', today(), 8);
    final pagesTodayAfter = await database.readingTimeDao.getTodayPages();
    expect(pagesTodayAfter, 8);
  });

  test('concurrent addPagesRead increments are not lost', () async {
    await database.readingTimeDao.addPagesRead('book1', today(), 1);

    await Future.wait([
      database.readingTimeDao.addPagesRead('book1', today(), 2),
      database.readingTimeDao.addPagesRead('book1', today(), 3),
    ]);

    final total = await database.readingTimeDao.getTodayPages();
    expect(total, 6);
  });
}

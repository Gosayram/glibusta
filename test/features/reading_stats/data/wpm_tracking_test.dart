// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/home/presentation/reading_stats_provider.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  group('addWpm', () {
    test('saves WPM for a new day', () async {
      final now = DateTime(2026, 8, 1, 14);
      await database.readingTimeDao.addWpm('book1', now, 200);

      final dailyWpm = await database.readingTimeDao.getDailyWpmLast7Days();
      final day = DateTime(2026, 8, 1);
      expect(dailyWpm[day], 200);
    });

    test('computes weighted average for multiple sessions on same day', () async {
      final now = DateTime(2026, 8, 1, 14);
      await database.readingTimeDao.addWpm('book1', now, 200);
      await database.readingTimeDao.addWpm('book1', now, 300);

      final dailyWpm = await database.readingTimeDao.getDailyWpmLast7Days();
      final day = DateTime(2026, 8, 1);
      expect(dailyWpm[day], 250);
    });

    test('ignores zero or negative WPM', () async {
      final now = DateTime(2026, 8, 1, 14);
      await database.readingTimeDao.addWpm('book1', now, 0);
      await database.readingTimeDao.addWpm('book1', now, -50);

      final dailyWpm = await database.readingTimeDao.getDailyWpmLast7Days();
      expect(dailyWpm, isEmpty);
    });
  });

  group('getAverageWpmLast7Days', () {
    test('returns 0 when no data', () async {
      final avg = await database.readingTimeDao.getAverageWpmLast7Days();
      expect(avg, 0);
    });

    test('returns weighted average across days', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      await database.readingTimeDao.addWpm('book1', today, 200);
      await database.readingTimeDao.addWpm('book1', yesterday, 300);

      final avg = await database.readingTimeDao.getAverageWpmLast7Days();
      expect(avg, 250);
    });
  });

  group('WpmTrend', () {
    test('unknown when less than 2 days of data', () {
      final trend = computeWpmTrend({
        DateTime(2026, 8, 1): 200,
      });
      expect(trend, WpmTrend.unknown);
    });

    test('up when recent day is significantly higher', () {
      final trend = computeWpmTrend({
        DateTime(2026, 7, 30): 150,
        DateTime(2026, 8, 1): 200,
      });
      expect(trend, WpmTrend.up);
    });

    test('down when recent day is significantly lower', () {
      final trend = computeWpmTrend({
        DateTime(2026, 7, 30): 250,
        DateTime(2026, 8, 1): 180,
      });
      expect(trend, WpmTrend.down);
    });

    test('stable when difference is within threshold', () {
      final trend = computeWpmTrend({
        DateTime(2026, 7, 30): 200,
        DateTime(2026, 8, 1): 205,
      });
      expect(trend, WpmTrend.stable);
    });
  });

  group('WPM saved on session end', () {
    test('session WPM persists and is queryable', () async {
      final now = DateTime(2026, 8, 1, 15);
      await database.readingTimeDao.addReadingTime('book1', now, 300);
      await database.readingTimeDao.addWpm('book1', now, 180);

      final avg = await database.readingTimeDao.getAverageWpmLast7Days();
      expect(avg, 180);

      final daily = await database.readingTimeDao.getDailyWpmLast7Days();
      final day = DateTime(2026, 8, 1);
      expect(daily.containsKey(day), isTrue);
      expect(daily[day], 180);
    });
  });
}

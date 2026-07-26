import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_stats/data/daily_reading_stats.dart';

void main() {
  group('DailyReadingStatsCollector', () {
    test('does not collect until the reader opts in', () {
      final collector = DailyReadingStatsCollector();
      const day = LocalReadingDay(2026, 7, 27);

      collector.recordInterval(
        startedAt: DateTime(2026, 7, 27, 10),
        endedAt: DateTime(2026, 7, 27, 10, 15),
      );

      expect(collector.durationFor(day), Duration.zero);
    });

    test('normalizes intervals to the device local calendar day', () {
      final collector = DailyReadingStatsCollector(enabled: true);
      final startedAt = DateTime.utc(2026, 7, 27, 20);
      final endingAt = startedAt.add(const Duration(minutes: 12));
      final localDay = LocalReadingDay.from(startedAt);

      collector.recordInterval(startedAt: startedAt, endedAt: endingAt);

      expect(collector.durationFor(localDay), const Duration(minutes: 12));
    });

    test('splits an interval between local days', () {
      final collector = DailyReadingStatsCollector(enabled: true);
      const firstDay = LocalReadingDay(2026, 7, 27);
      const secondDay = LocalReadingDay(2026, 7, 28);

      collector.recordInterval(
        startedAt: DateTime(2026, 7, 27, 23, 55),
        endedAt: DateTime(2026, 7, 28, 0, 10),
      );

      expect(collector.durationFor(firstDay), const Duration(minutes: 5));
      expect(collector.durationFor(secondDay), const Duration(minutes: 10));
    });

    test('ignores zero and negative intervals caused by a clock rollback', () {
      final collector = DailyReadingStatsCollector(enabled: true);
      const day = LocalReadingDay(2026, 7, 27);

      collector.recordInterval(
        startedAt: DateTime(2026, 7, 27, 10),
        endedAt: DateTime(2026, 7, 27, 9, 59),
      );
      collector.recordInterval(
        startedAt: DateTime(2026, 7, 27, 10),
        endedAt: DateTime(2026, 7, 27, 10),
      );

      expect(collector.durationFor(day), Duration.zero);
    });

    test('returns a zero-filled seven-day local trend in chronological order', () {
      final collector = DailyReadingStatsCollector(enabled: true);
      const day = LocalReadingDay(2026, 7, 27);
      collector.recordInterval(
        startedAt: DateTime(2026, 7, 27, 12),
        endedAt: DateTime(2026, 7, 27, 12, 20),
      );

      final trend = collector.sevenDayTrend(DateTime(2026, 7, 27, 23, 59));

      expect(trend, hasLength(7));
      expect(trend.first.day, const LocalReadingDay(2026, 7, 21));
      expect(trend.last.day, day);
      expect(trend.last.duration, const Duration(minutes: 20));
      expect(trend.take(6).map((total) => total.duration), everyElement(Duration.zero));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/home/presentation/reading_stats_provider.dart';
import 'package:glibusta/features/reading_stats/data/reading_trend.dart';

void main() {
  group('buildReadingMinutesTrend', () {
    test('groups local readings, zero-fills missing days, and keeps chronological order', () {
      final trend = buildReadingMinutesTrend(
        readings: [
          DayReading(date: DateTime(2026, 7, 26, 8), minutes: 15),
          DayReading(date: DateTime(2026, 7, 26, 21), minutes: 10),
          DayReading(date: DateTime(2026, 7, 28, 8), minutes: 25),
        ],
        endingAt: DateTime(2026, 7, 28, 23, 59),
        period: ReadingTrendPeriod.week,
      );

      expect(trend, hasLength(7));
      expect(trend.first.date, DateTime(2026, 7, 22));
      expect(trend.last.date, DateTime(2026, 7, 28));
      expect(trend[4].minutes, 25);
      expect(trend[5].minutes, 0);
      expect(trend[6].minutes, 25);
    });

    test('creates 30 local calendar days for the monthly view', () {
      final trend = buildReadingMinutesTrend(
        readings: const [],
        endingAt: DateTime(2026, 3, 1, 12),
        period: ReadingTrendPeriod.month,
      );

      expect(trend, hasLength(30));
      expect(trend.first.date, DateTime(2026, 1, 31));
      expect(trend.last.date, DateTime(2026, 3));
      expect(trend.map((day) => day.minutes), everyElement(0));
    });
  });
}

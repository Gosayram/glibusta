import 'package:flutter/foundation.dart';

import '../../home/presentation/reading_stats_provider.dart';

/// The period displayed by the local reading-rhythm chart.
enum ReadingTrendPeriod {
  week(days: 7, label: 'За неделю'),
  month(days: 30, label: 'За месяц');

  const ReadingTrendPeriod({required this.days, required this.label});

  final int days;
  final String label;
}

/// One local calendar day in a reading-rhythm trend.
@immutable
final class ReadingTrendDay {
  const ReadingTrendDay({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;
}

/// Produces a chronological, zero-filled local-day trend.
///
/// [DayReading] is already derived from locally stored reading sessions. The
/// calendar-day keys deliberately discard the time component so multiple
/// sessions never create duplicate bars for the same local day.
List<ReadingTrendDay> buildReadingMinutesTrend({
  required Iterable<DayReading> readings,
  required DateTime endingAt,
  required ReadingTrendPeriod period,
}) {
  final minutesByDay = <DateTime, int>{};
  for (final reading in readings) {
    final local = reading.date.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    minutesByDay.update(
      day,
      (minutes) => minutes + reading.minutes,
      ifAbsent: () => reading.minutes,
    );
  }

  final localEnd = endingAt.toLocal();
  var day = DateTime(
    localEnd.year,
    localEnd.month,
    localEnd.day,
  ).subtract(Duration(days: period.days - 1));

  return List<ReadingTrendDay>.generate(period.days, (_) {
    final trendDay = ReadingTrendDay(date: day, minutes: minutesByDay[day] ?? 0);
    day = day.add(const Duration(days: 1));
    return trendDay;
  });
}

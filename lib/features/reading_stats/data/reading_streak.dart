import 'package:flutter/foundation.dart';

/// Local-calendar reading streaks derived from days with positive reading time.
@immutable
final class ReadingStreak {
  const ReadingStreak({
    required this.currentDays,
    required this.longestDays,
    required this.needsReadingToday,
  });

  /// Consecutive active days that are still valid at the calculation time.
  final int currentDays;

  /// Longest uninterrupted sequence in the bounded local history.
  final int longestDays;

  /// True when yesterday's streak is preserved until the end of today.
  final bool needsReadingToday;
}

/// Calculates local-calendar streaks without expiring yesterday's reading early.
///
/// A reader who read yesterday still has an active streak until local midnight.
/// Future timestamps and dates outside [historyDays] are ignored so imported or
/// clock-skewed data cannot inflate the result.
ReadingStreak calculateReadingStreak({
  required Iterable<DateTime> activeDays,
  required DateTime endingAt,
  int historyDays = 365,
}) {
  assert(historyDays > 0, 'Streak history must include at least one day.');

  final today = _localDay(endingAt);
  final oldest = DateTime(today.year, today.month, today.day - historyDays + 1);
  final days = <DateTime>{
    for (final date in activeDays)
      if (!_localDay(date).isAfter(today) && !_localDay(date).isBefore(oldest)) _localDay(date),
  };

  final streakStart = days.contains(today) ? today : _previousDay(today);
  var currentDays = 0;
  for (
    var day = streakStart;
    currentDays < historyDays && days.contains(day);
    day = _previousDay(day)
  ) {
    currentDays++;
  }

  final sortedDays = days.toList()..sort();
  var longestDays = 0;
  var runLength = 0;
  DateTime? previous;
  for (final day in sortedDays) {
    runLength = previous == null || day != _nextDay(previous) ? 1 : runLength + 1;
    if (runLength > longestDays) longestDays = runLength;
    previous = day;
  }

  return ReadingStreak(
    currentDays: currentDays,
    longestDays: longestDays,
    needsReadingToday: currentDays > 0 && !days.contains(today),
  );
}

DateTime _localDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _previousDay(DateTime day) => DateTime(day.year, day.month, day.day - 1);

DateTime _nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

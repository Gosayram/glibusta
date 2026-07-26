import 'package:flutter/foundation.dart';

/// A calendar day in the device's local time zone.
///
/// Keeping the date separate from [DateTime] avoids accidentally grouping
/// readings by an instant's UTC date rather than the reader's local day.
@immutable
final class LocalReadingDay implements Comparable<LocalReadingDay> {
  const LocalReadingDay(this.year, this.month, this.day);

  factory LocalReadingDay.from(DateTime time) {
    final local = time.toLocal();
    return LocalReadingDay(local.year, local.month, local.day);
  }

  final int year;
  final int month;
  final int day;

  DateTime get start => DateTime(year, month, day);

  LocalReadingDay previous() {
    return LocalReadingDay.from(DateTime(year, month, day - 1));
  }

  LocalReadingDay next() {
    return LocalReadingDay.from(DateTime(year, month, day + 1));
  }

  @override
  int compareTo(LocalReadingDay other) => start.compareTo(other.start);

  @override
  bool operator ==(Object other) {
    return other is LocalReadingDay &&
        year == other.year &&
        month == other.month &&
        day == other.day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// An immutable daily reading total suitable for a future, user-enabled UI.
@immutable
final class DailyReadingTotal {
  const DailyReadingTotal({
    required this.day,
    required this.duration,
  });

  final LocalReadingDay day;
  final Duration duration;
}

/// Collects only explicitly enabled, positive reading intervals.
///
/// This has no persistence or UI dependency. Callers own opt-in preference
/// storage and can expose the collected data only after the reader enables it.
final class DailyReadingStatsCollector {
  DailyReadingStatsCollector({bool enabled = false}) : _enabled = enabled;

  bool _enabled;
  final Map<LocalReadingDay, Duration> _durations = {};

  bool get enabled => _enabled;

  void setEnabled(bool enabled) => _enabled = enabled;

  /// Adds an interval, splitting it at local-midnight boundaries.
  ///
  /// A wall-clock rollback produces a non-positive interval and is ignored.
  void recordInterval({
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    if (!_enabled) return;

    var cursor = startedAt.toLocal();
    final end = endedAt.toLocal();
    if (!end.isAfter(cursor)) return;

    while (cursor.isBefore(end)) {
      final day = LocalReadingDay.from(cursor);
      final nextMidnight = day.next().start;
      final segmentEnd = end.isBefore(nextMidnight) ? end : nextMidnight;
      final duration = segmentEnd.difference(cursor);
      if (duration.inMicroseconds > 0) {
        _durations.update(day, (value) => value + duration, ifAbsent: () => duration);
      }
      cursor = segmentEnd;
    }
  }

  Duration durationFor(LocalReadingDay day) => _durations[day] ?? Duration.zero;

  /// Returns the seven local calendar days ending with [endingAt], oldest first.
  List<DailyReadingTotal> sevenDayTrend(DateTime endingAt) {
    var day = LocalReadingDay.from(endingAt);
    for (var index = 1; index < 7; index++) {
      day = day.previous();
    }

    return List<DailyReadingTotal>.generate(7, (index) {
      final total = DailyReadingTotal(day: day, duration: durationFor(day));
      day = day.next();
      return total;
    });
  }
}

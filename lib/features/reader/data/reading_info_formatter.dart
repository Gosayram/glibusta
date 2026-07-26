/// Formats reading-time estimates for compact reader information slots.
String formatReadingTimeEstimate(int minutes) {
  if (minutes <= 0) return '—';
  if (minutes < 60) return '~$minutes мин';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '~$hours ч' : '~$hours ч $remainingMinutes мин';
}

/// Estimates the remaining time in the current chapter from the book-level
/// estimate. The parser does not always expose per-chapter word counts, so an
/// average over the current and following chapters is more honest than
/// presenting a percentage as a time value.
String formatCurrentChapterTimeEstimate({
  required int bookMinutesLeft,
  required int chaptersRemaining,
}) {
  if (bookMinutesLeft <= 0 || chaptersRemaining <= 0) return '—';
  return formatReadingTimeEstimate((bookMinutesLeft / chaptersRemaining).ceil());
}

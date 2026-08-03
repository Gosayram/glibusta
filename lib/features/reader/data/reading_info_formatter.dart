/// Formats reading-time estimates for compact reader information slots.
///
/// Display rules:
/// - ≤ 0 min → "—" (no estimate)
/// - < 1 min → "< 1 мин"
/// - 1–59 min → "~X мин"
/// - 1–23 h → "~X ч Y мин"
/// - ≥ 24 h → "~X д Y ч" (days only, no minutes)
String formatReadingTimeEstimate(int minutes) {
  if (minutes <= 0) return '—';
  if (minutes < 1) return '< 1 мин';
  if (minutes < 60) return '~$minutes мин';

  final totalHours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (totalHours >= 24) {
    final days = totalHours ~/ 24;
    final remainingHours = totalHours % 24;
    return remainingHours == 0 ? '~$days д' : '~$days д $remainingHours ч';
  }

  return remainingMinutes == 0 ? '~$totalHours ч' : '~$totalHours ч $remainingMinutes мин';
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

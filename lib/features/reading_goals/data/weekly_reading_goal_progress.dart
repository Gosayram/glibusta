import 'package:flutter/foundation.dart';

/// A transparent seven-day view of an enabled daily reading goal.
///
/// This is intentionally derived rather than persisted: changing a daily goal
/// immediately updates the weekly target without creating a second setting.
@immutable
final class WeeklyReadingGoalProgress {
  const WeeklyReadingGoalProgress({
    required this.completedMinutes,
    required this.targetMinutes,
  });

  final int completedMinutes;
  final int targetMinutes;

  bool get isComplete => completedMinutes >= targetMinutes;

  double get completion =>
      targetMinutes <= 0 ? 0.0 : (completedMinutes / targetMinutes).clamp(0.0, 1.0);
}

/// Calculates the current local calendar week's target from a daily goal.
WeeklyReadingGoalProgress calculateWeeklyReadingGoalProgress({
  required int dailyGoalMinutes,
  required int weekMinutes,
}) {
  assert(dailyGoalMinutes > 0, 'A weekly goal requires a positive daily goal.');
  assert(weekMinutes >= 0, 'Reading time cannot be negative.');

  return WeeklyReadingGoalProgress(
    completedMinutes: weekMinutes,
    targetMinutes: dailyGoalMinutes * DateTime.daysPerWeek,
  );
}

String formatWeeklyGoalProgressMessage(WeeklyReadingGoalProgress progress) {
  if (progress.completedMinutes == progress.targetMinutes) {
    return 'Недельная цель выполнена точно';
  }
  if (progress.isComplete) {
    return 'На ${progress.completedMinutes - progress.targetMinutes} мин больше цели';
  }
  return 'Осталось ${progress.targetMinutes - progress.completedMinutes} мин';
}

import 'package:flutter/foundation.dart';

/// The locally measurable value behind a reading milestone.
enum ReadingMilestoneMetric {
  totalMinutes,
  sessions,
  longestStreak,
}

/// A transparent, local-only reading achievement.
///
/// Unlike an estimated page count or WPM, every [currentValue] comes directly
/// from a persisted reading session aggregate.
@immutable
final class ReadingMilestone {
  const ReadingMilestone({
    required this.metric,
    required this.title,
    required this.description,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
  });

  final ReadingMilestoneMetric metric;
  final String title;
  final String description;
  final int currentValue;
  final int targetValue;
  final String unit;

  bool get isUnlocked => currentValue >= targetValue;

  double get progress => (currentValue / targetValue).clamp(0, 1).toDouble();

  String get progressLabel => '$currentValue из $targetValue $unit';
}

/// Builds milestones solely from established, local reading totals.
///
/// The function deliberately does not infer pages, words, or a reading speed:
/// the current data model has no reliable source for those values.
List<ReadingMilestone> buildLocalReadingMilestones({
  required int totalMinutes,
  required int totalSessions,
  required int longestStreak,
}) {
  final safeMinutes = totalMinutes < 0 ? 0 : totalMinutes;
  final safeSessions = totalSessions < 0 ? 0 : totalSessions;
  final safeStreak = longestStreak < 0 ? 0 : longestStreak;

  return [
    ReadingMilestone(
      metric: ReadingMilestoneMetric.totalMinutes,
      title: 'Первый час с книгой',
      description: '60 минут локального времени чтения',
      currentValue: safeMinutes,
      targetValue: 60,
      unit: 'мин',
    ),
    ReadingMilestone(
      metric: ReadingMilestoneMetric.sessions,
      title: 'Регулярный читатель',
      description: '25 сохранённых сессий',
      currentValue: safeSessions,
      targetValue: 25,
      unit: 'сессий',
    ),
    ReadingMilestone(
      metric: ReadingMilestoneMetric.longestStreak,
      title: 'Неделя с книгой',
      description: 'Лучшая серия в 7 календарных дней',
      currentValue: safeStreak,
      targetValue: 7,
      unit: 'дней',
    ),
    ReadingMilestone(
      metric: ReadingMilestoneMetric.totalMinutes,
      title: 'Десять часов чтения',
      description: '600 минут локального времени чтения',
      currentValue: safeMinutes,
      targetValue: 600,
      unit: 'мин',
    ),
  ];
}

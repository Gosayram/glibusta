import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../reading_stats/data/reading_streak.dart';

part 'reading_stats_provider.g.dart';

class DayReading {
  final DateTime date;
  final int minutes;

  const DayReading({required this.date, required this.minutes});
}

class ReadingStats {
  final int currentStreak;
  final int longestStreak;
  final int todayMinutes;
  final int thisWeekMinutes;
  final int thisMonthMinutes;
  final int totalMinutes;
  final int totalSessions;
  final List<DayReading> heatmapData;

  const ReadingStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.todayMinutes,
    required this.thisWeekMinutes,
    required this.thisMonthMinutes,
    required this.totalMinutes,
    required this.totalSessions,
    required this.heatmapData,
  });

  double get avgSessionMinutes =>
      totalSessions > 0 ? (totalMinutes / totalSessions).roundToDouble() : 0;

  String get todayText {
    if (todayMinutes == 0) return 'Сегодня не читали';
    if (todayMinutes < 60) return '$todayMinutes мин сегодня';
    final h = todayMinutes ~/ 60;
    final m = todayMinutes % 60;
    return m > 0 ? '$h ч $m мин сегодня' : '$h ч сегодня';
  }

  String get streakText {
    if (currentStreak == 0) return 'Нет серии';
    if (currentStreak == 1) return '1 день подряд';
    if (currentStreak < 5) return '$currentStreak дня подряд';
    return '$currentStreak дней подряд';
  }

  String get monthText {
    if (thisMonthMinutes == 0) return 'В этом месяце не читали';
    final h = thisMonthMinutes ~/ 60;
    final m = thisMonthMinutes % 60;
    if (h == 0) return '$thisMonthMinutes мин за месяц';
    return m > 0 ? '$h ч $m мин за месяц' : '$h ч за месяц';
  }
}

int _sessionMinutes(ReadingSession s) {
  final end = s.endedAt ?? DateTime.now();
  return end.difference(s.startedAt).inMinutes;
}

@riverpod
Future<ReadingStats> readingStats(Ref ref) async {
  final db = ref.watch(databaseProvider);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month);

  final todaySessions = await db.bookDao.getSessionsForDateRange(todayStart, now);
  final weekSessions = await db.bookDao.getSessionsForDateRange(weekStart, now);
  final monthSessions = await db.bookDao.getSessionsForDateRange(monthStart, now);
  final allSessions = await db.bookDao.getSessionsForDateRange(
    now.subtract(const Duration(days: 365)),
    now,
  );

  final todayMinutes = todaySessions.fold<int>(0, (sum, s) => sum + _sessionMinutes(s));
  final weekMinutes = weekSessions.fold<int>(0, (sum, s) => sum + _sessionMinutes(s));
  final monthMinutes = monthSessions.fold<int>(0, (sum, s) => sum + _sessionMinutes(s));
  final totalMinutes = allSessions.fold<int>(0, (sum, s) => sum + _sessionMinutes(s));

  final dailyMinutes = <DateTime, int>{};
  for (final session in allSessions) {
    final day = DateTime(session.startedAt.year, session.startedAt.month, session.startedAt.day);
    final minutes = _sessionMinutes(session);
    dailyMinutes[day] = (dailyMinutes[day] ?? 0) + minutes;
  }

  final streak = calculateReadingStreak(
    activeDays: dailyMinutes.entries.where((entry) => entry.value > 0).map((entry) => entry.key),
    endingAt: now,
  );

  final heatmapData = <DayReading>[];
  for (int i = 111; i >= 0; i--) {
    final day = todayStart.subtract(Duration(days: i));
    heatmapData.add(
      DayReading(
        date: day,
        minutes: dailyMinutes[day] ?? 0,
      ),
    );
  }

  return ReadingStats(
    currentStreak: streak.currentDays,
    longestStreak: streak.longestDays,
    todayMinutes: todayMinutes,
    thisWeekMinutes: weekMinutes,
    thisMonthMinutes: monthMinutes,
    totalMinutes: totalMinutes,
    totalSessions: allSessions.length,
    heatmapData: heatmapData,
  );
}

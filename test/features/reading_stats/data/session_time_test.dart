// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('session duration formatting', () {
    String formatSessionDuration(int minutes) {
      if (minutes < 1) return '< 1 мин';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (h == 0) return '$m мин';
      return m > 0 ? '$h ч $m мин' : '$h ч';
    }

    test('formats zero minutes as < 1 мин', () {
      expect(formatSessionDuration(0), '< 1 мин');
    });

    test('formats minutes under an hour', () {
      expect(formatSessionDuration(25), '25 мин');
    });

    test('formats exact hours', () {
      expect(formatSessionDuration(120), '2 ч');
    });

    test('formats hours with remaining minutes', () {
      expect(formatSessionDuration(95), '1 ч 35 мин');
    });
  });

  group('today and week reading time calculation', () {
    int sessionMinutes(DateTime startedAt, DateTime? endedAt) {
      final end = endedAt ?? DateTime.now();
      return end.difference(startedAt).inMinutes;
    }

    int sumSessionMinutes(List<(DateTime, DateTime?)> sessions) {
      return sessions.fold<int>(0, (sum, s) => sum + sessionMinutes(s.$1, s.$2));
    }

    List<(DateTime, DateTime?)> filterByDateRange(
      List<(DateTime, DateTime?)> sessions,
      DateTime start,
      DateTime end,
    ) {
      return sessions.where((s) {
        return !s.$1.isBefore(start) && !s.$1.isAfter(end);
      }).toList();
    }

    test('calculates today reading time correctly', () {
      final now = DateTime(2026, 8, 1, 15, 30);
      final todayStart = DateTime(now.year, now.month, now.day);

      final sessions = [
        (DateTime(2026, 8, 1, 9, 0), DateTime(2026, 8, 1, 9, 30)),
        (DateTime(2026, 8, 1, 14, 0), DateTime(2026, 8, 1, 14, 45)),
        (DateTime(2026, 7, 31, 23, 0), DateTime(2026, 7, 31, 23, 30)),
      ];

      final todaySessions = filterByDateRange(sessions, todayStart, now);
      final todayMinutes = sumSessionMinutes(todaySessions);

      expect(todayMinutes, 75);
    });

    test('calculates this week reading time correctly', () {
      final now = DateTime(2026, 8, 1, 15, 30);
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      final sessions = [
        (DateTime(2026, 7, 28, 10, 0), DateTime(2026, 7, 28, 10, 30)),
        (DateTime(2026, 7, 30, 20, 0), DateTime(2026, 7, 30, 20, 45)),
        (DateTime(2026, 8, 1, 9, 0), DateTime(2026, 8, 1, 9, 20)),
        (DateTime(2026, 7, 25, 10, 0), DateTime(2026, 7, 25, 11, 0)),
      ];

      final weekSessions = filterByDateRange(sessions, weekStart, now);
      final weekMinutes = sumSessionMinutes(weekSessions);

      expect(weekMinutes, 95);
    });

    test('returns zero when no sessions in range', () {
      final now = DateTime(2026, 8, 1, 15, 30);
      final todayStart = DateTime(now.year, now.month, now.day);

      final sessions = <(DateTime, DateTime?)>[
        (DateTime(2026, 7, 30, 10, 0), DateTime(2026, 7, 30, 10, 30)),
      ];

      final todaySessions = filterByDateRange(sessions, todayStart, now);
      final todayMinutes = sumSessionMinutes(todaySessions);

      expect(todayMinutes, 0);
    });

    test('handles active session without endedAt', () {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 15));
      final minutes = sessionMinutes(startedAt, null);

      expect(minutes, greaterThanOrEqualTo(0));
    });
  });
}

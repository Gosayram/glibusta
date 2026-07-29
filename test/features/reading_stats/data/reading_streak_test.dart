import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_stats/data/reading_streak.dart';

void main() {
  group('calculateReadingStreak', () {
    test('keeps yesterday’s streak active until the current local day ends', () {
      final streak = calculateReadingStreak(
        activeDays: [
          DateTime(2026, 7, 27, 22),
          DateTime(2026, 7, 28, 7),
        ],
        endingAt: DateTime(2026, 7, 29, 9),
      );

      expect(streak.currentDays, 2);
      expect(streak.longestDays, 2);
      expect(streak.needsReadingToday, isTrue);
    });

    test('extends the current streak when the reader is active today', () {
      final streak = calculateReadingStreak(
        activeDays: [
          DateTime(2026, 7, 27),
          DateTime(2026, 7, 28),
          DateTime(2026, 7, 29, 8),
        ],
        endingAt: DateTime(2026, 7, 29, 9),
      );

      expect(streak.currentDays, 3);
      expect(streak.needsReadingToday, isFalse);
    });

    test('does not revive a streak after a missed calendar day', () {
      final streak = calculateReadingStreak(
        activeDays: [
          DateTime(2026, 7, 25),
          DateTime(2026, 7, 27),
        ],
        endingAt: DateTime(2026, 7, 29),
      );

      expect(streak.currentDays, 0);
      expect(streak.longestDays, 1);
      expect(streak.needsReadingToday, isFalse);
    });

    test('normalizes duplicate timestamps and ignores future days', () {
      final streak = calculateReadingStreak(
        activeDays: [
          DateTime(2026, 7, 28, 8),
          DateTime(2026, 7, 28, 20),
          DateTime(2026, 7, 29, 8),
          DateTime(2026, 7, 30),
        ],
        endingAt: DateTime(2026, 7, 29, 9),
      );

      expect(streak.currentDays, 2);
      expect(streak.longestDays, 2);
    });
  });
}

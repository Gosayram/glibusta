import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_goals/data/weekly_reading_goal_progress.dart';

void main() {
  group('calculateWeeklyReadingGoalProgress', () {
    test('derives a seven-day target from the daily goal', () {
      final progress = calculateWeeklyReadingGoalProgress(
        dailyGoalMinutes: 30,
        weekMinutes: 125,
      );

      expect(progress.targetMinutes, 210);
      expect(progress.completedMinutes, 125);
      expect(progress.completion, closeTo(125 / 210, 0.0001));
      expect(formatWeeklyGoalProgressMessage(progress), 'Осталось 85 мин');
    });

    test('clamps the visual progress but preserves time beyond the target', () {
      final progress = calculateWeeklyReadingGoalProgress(
        dailyGoalMinutes: 20,
        weekMinutes: 155,
      );

      expect(progress.targetMinutes, 140);
      expect(progress.isComplete, isTrue);
      expect(progress.completion, 1);
      expect(formatWeeklyGoalProgressMessage(progress), 'На 15 мин больше цели');
    });
  });
}

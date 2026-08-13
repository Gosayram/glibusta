import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_stats/data/reading_milestones.dart';

void main() {
  group('buildLocalReadingMilestones', () {
    test('uses only supplied local aggregates and clamps progress', () {
      final milestones = buildLocalReadingMilestones(
        totalMinutes: 720,
        totalSessions: 30,
        longestStreak: 8,
      );

      expect(milestones, hasLength(4));
      expect(milestones.map((milestone) => milestone.isUnlocked), everyElement(isTrue));
      expect(milestones.first.progress, 1);
      expect(milestones.first.progressLabel, '720 из 60 мин');
    });

    test('keeps a locked milestone honest when only part of its source exists', () {
      final milestones = buildLocalReadingMilestones(
        totalMinutes: 45,
        totalSessions: 0,
        longestStreak: 2,
      );

      expect(milestones[0].isUnlocked, isFalse);
      expect(milestones[0].progress, closeTo(0.75, 0.001));
      expect(milestones[1].currentValue, 0);
      expect(milestones[2].progressLabel, '2 из 7 дней');
    });

    test('does not turn invalid negative aggregates into achievements', () {
      final milestones = buildLocalReadingMilestones(
        totalMinutes: -1,
        totalSessions: -1,
        longestStreak: -1,
      );

      expect(milestones.map((milestone) => milestone.currentValue), everyElement(0));
      expect(milestones.map((milestone) => milestone.isUnlocked), everyElement(isFalse));
    });
  });
}

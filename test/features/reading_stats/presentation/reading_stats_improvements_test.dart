import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/home/presentation/reading_stats_provider.dart';
import 'package:glibusta/features/reading_goals/data/reading_goal_repository.dart';
import 'package:glibusta/features/reading_goals/presentation/reading_goal_provider.dart';
import 'package:glibusta/features/reading_stats/data/reading_stats_providers.dart';
import 'package:glibusta/features/reading_stats/presentation/reading_stats_screen.dart';

void main() {
  Widget buildTestWidget({
    ReadingStats? stats,
    ReadingGoal? goal,
  }) {
    return ProviderScope(
      overrides: [
        readingStatsProvider.overrideWithValue(
          AsyncData(
            stats ??
                const ReadingStats(
                  currentStreak: 0,
                  longestStreak: 0,
                  todayMinutes: 0,
                  todayPages: 0,
                  thisWeekMinutes: 0,
                  thisMonthMinutes: 0,
                  totalMinutes: 0,
                  totalSessions: 0,
                  averageWpm: 0,
                  wpmTrend: WpmTrend.stable,
                  heatmapData: [],
                ),
          ),
        ),
        readingGoalProvider.overrideWithValue(
          AsyncData(
            goal ??
                const ReadingGoal(
                  dailyMinutes: 60,
                ),
          ),
        ),
        bookStatsListProvider.overrideWithValue(const AsyncData({})),
        favoriteGenresProvider.overrideWithValue(
          const AsyncData<List<MapEntry<String, int>>>([]),
        ),
        readingHoursProvider.overrideWithValue(
          AsyncData(List<int>.filled(24, 0)),
        ),
        sessionTimerProvider.overrideWith(
          (ref) => Stream<DateTime>.value(DateTime.now()),
        ),
      ],
      child: const MaterialApp(home: ReadingStatsScreen()),
    );
  }

  group('Streak banner', () {
    testWidgets('shows zero streak with start reading message', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Начните читать сегодня!'), findsOneWidget);
    });

    testWidgets('shows 1-day streak', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: const ReadingStats(
            currentStreak: 1,
            longestStreak: 5,
            todayMinutes: 30,
            todayPages: 0,
            thisWeekMinutes: 30,
            thisMonthMinutes: 30,
            totalMinutes: 30,
            totalSessions: 1,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets);
      expect(find.text('1 день подряд'), findsWidgets);
    });

    testWidgets('shows multi-day streak with record', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: const ReadingStats(
            currentStreak: 5,
            longestStreak: 10,
            todayMinutes: 30,
            todayPages: 0,
            thisWeekMinutes: 150,
            thisMonthMinutes: 150,
            totalMinutes: 150,
            totalSessions: 5,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsWidgets);
      expect(find.text('5 дней подряд'), findsWidgets);
      expect(find.text('Рекорд'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });
  });

  group('Today progress card', () {
    testWidgets('shows goal progress when enabled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: const ReadingStats(
            currentStreak: 0,
            longestStreak: 0,
            todayMinutes: 30,
            todayPages: 0,
            thisWeekMinutes: 30,
            thisMonthMinutes: 30,
            totalMinutes: 30,
            totalSessions: 1,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: [],
          ),
          goal: const ReadingGoal(dailyMinutes: 60, isEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Сегодня'), findsWidgets);
      expect(find.text('30 из 60 мин'), findsOneWidget);
      expect(find.text('Осталось 30 мин'), findsOneWidget);
    });

    testWidgets('shows celebration when goal met', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: const ReadingStats(
            currentStreak: 1,
            longestStreak: 1,
            todayMinutes: 60,
            todayPages: 0,
            thisWeekMinutes: 60,
            thisMonthMinutes: 60,
            totalMinutes: 60,
            totalSessions: 1,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: [],
          ),
          goal: const ReadingGoal(dailyMinutes: 60, isEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🎉'), findsOneWidget);
      expect(find.text('60 из 60 мин'), findsOneWidget);
    });

    testWidgets('hides when goal disabled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          goal: const ReadingGoal(dailyMinutes: 60),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30 из 60 мин'), findsNothing);
    });
  });

  group('Weekly goal chart', () {
    testWidgets('renders 7 bars when goal enabled', (tester) async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final heatmapData = List.generate(
        14,
        (i) => DayReading(
          date: todayStart.subtract(Duration(days: i)),
          minutes: i < 7 ? (i + 1) * 10 : 0,
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          stats: ReadingStats(
            currentStreak: 3,
            longestStreak: 3,
            todayMinutes: 10,
            todayPages: 0,
            thisWeekMinutes: 70,
            thisMonthMinutes: 70,
            totalMinutes: 70,
            totalSessions: 3,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: heatmapData,
          ),
          goal: const ReadingGoal(dailyMinutes: 20, isEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Прогресс за неделю'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Прогресс за неделю'), findsOneWidget);

      final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final greenBars = decoratedBoxes
          .whereType<DecoratedBox>()
          .where((w) => w.decoration is BoxDecoration)
          .map((w) => w.decoration as BoxDecoration)
          .where((d) => d.color == Colors.green);
      expect(greenBars.length, greaterThanOrEqualTo(1));
    });

    testWidgets('hides when goal disabled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          goal: const ReadingGoal(dailyMinutes: 60),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Прогресс за неделю'), findsNothing);
    });
  });
}

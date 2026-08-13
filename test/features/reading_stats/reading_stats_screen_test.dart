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
        bookStatsListProvider.overrideWithValue(
          const AsyncData({}),
        ),
        favoriteGenresProvider.overrideWithValue(
          const AsyncData<List<MapEntry<String, int>>>([]),
        ),
        readingHoursProvider.overrideWithValue(
          AsyncData(List<int>.filled(24, 0)),
        ),
        currentSessionStartProvider.overrideWithValue(null),
        sessionTimerProvider.overrideWith(
          (ref) => Stream<DateTime>.value(DateTime.now()),
        ),
      ],
      child: const MaterialApp(
        home: ReadingStatsScreen(),
      ),
    );
  }

  group('ReadingStatsScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Статистика чтения'), findsOneWidget);
    });

    testWidgets('shows summary cards section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Серия'), findsOneWidget);
      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('За месяц'), findsOneWidget);
    });

    testWidgets('shows export menu button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('renders list view body', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('shows heatmap card area', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('shows transparent local achievement progress', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: const ReadingStats(
            currentStreak: 2,
            longestStreak: 2,
            todayMinutes: 45,
            todayPages: 0,
            thisWeekMinutes: 45,
            thisMonthMinutes: 45,
            totalMinutes: 45,
            totalSessions: 3,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Локальные достижения'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Считаются только по сохранённым данным на этом устройстве'),
        findsOneWidget,
      );
      expect(find.text('45 из 60 мин'), findsOneWidget);
      expect(find.text('2 из 7 дней'), findsOneWidget);
    });

    testWidgets('shows a derived seven-day target for an enabled goal', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: const ReadingStats(
            currentStreak: 0,
            longestStreak: 0,
            todayMinutes: 15,
            todayPages: 0,
            thisWeekMinutes: 125,
            thisMonthMinutes: 125,
            totalMinutes: 125,
            totalSessions: 1,
            averageWpm: 0,
            wpmTrend: WpmTrend.stable,
            heatmapData: [],
          ),
          goal: const ReadingGoal(isEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ритм за неделю'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ритм за неделю'), findsOneWidget);
      expect(find.text('125 из 210 мин'), findsOneWidget);
      expect(find.text('Осталось 85 мин'), findsOneWidget);
    });

    test('formats remaining, exact, and exceeded daily-goal states', () {
      expect(
        formatDailyGoalProgressMessage(todayMinutes: 20, goalMinutes: 30),
        'Осталось 10 мин',
      );
      expect(
        formatDailyGoalProgressMessage(todayMinutes: 30, goalMinutes: 30),
        'Цель выполнена точно',
      );
      expect(
        formatDailyGoalProgressMessage(todayMinutes: 45, goalMinutes: 30),
        'На 15 мин больше цели',
      );
    });
  });
}

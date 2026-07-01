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
                  thisWeekMinutes: 0,
                  thisMonthMinutes: 0,
                  totalMinutes: 0,
                  totalSessions: 0,
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
      expect(find.text('За неделю'), findsOneWidget);
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
  });
}

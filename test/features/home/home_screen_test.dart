import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/collections/presentation/collections_screen.dart';
import 'package:glibusta/features/home/data/home_providers.dart';
import 'package:glibusta/features/home/presentation/continue_reading_provider.dart';
import 'package:glibusta/features/home/presentation/home_screen.dart';
import 'package:glibusta/features/home/presentation/reading_stats_provider.dart';
import 'package:glibusta/features/library/presentation/pinned_books_provider.dart';

const _emptyStats = ReadingStats(
  currentStreak: 0,
  longestStreak: 0,
  todayMinutes: 0,
  thisWeekMinutes: 0,
  thisMonthMinutes: 0,
  totalMinutes: 0,
  heatmapData: [],
);

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        recentBooksProvider.overrideWithValue(const AsyncData([])),
        continueReadingInfosProvider.overrideWithValue(const AsyncData([])),
        pinnedBooksListProvider.overrideWithValue(const AsyncData([])),
        userCollectionsProvider.overrideWithValue(const AsyncData([])),
        readingStatsProvider.overrideWithValue(const AsyncData(_emptyStats)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  group('HomeScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Glibusta'), findsOneWidget);
    });

    testWidgets('shows section headers', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Продолжить чтение'), findsOneWidget);
      expect(find.text('Статистика чтения'), findsOneWidget);
    });

    testWidgets('shows empty state for continue reading', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Начните читать книгу'), findsOneWidget);
    });
  });
}

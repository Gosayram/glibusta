import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_stats/data/reading_trend.dart';
import 'package:glibusta/features/reading_stats/presentation/reading_trend_card.dart';

void main() {
  Widget buildChart(List<ReadingTrendDay> trend) {
    return MaterialApp(
      home: Scaffold(
        body: ReadingTrendChart(trend: trend),
      ),
    );
  }

  group('ReadingTrendChart', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 24), minutes: 10),
          ReadingTrendDay(date: DateTime(2026, 7, 25), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 25),
        ]),
      );

      expect(find.byType(ReadingTrendChart), findsOneWidget);
    });

    testWidgets('summarises a local reading trend with one accessible label', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 20),
        ]),
      );

      expect(
        tester.getSemantics(find.byType(ReadingTrendChart)),
        matchesSemantics(
          label: 'Ритм чтения: 1 активный день, 20 минут за выбранный период',
        ),
      );
      semantics.dispose();
    });

    testWidgets('shows total minutes in summary', (tester) async {
      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 22), minutes: 15),
          ReadingTrendDay(date: DateTime(2026, 7, 23), minutes: 30),
          ReadingTrendDay(date: DateTime(2026, 7, 24), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 25), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 28), minutes: 10),
        ]),
      );

      expect(find.text('55 мин'), findsOneWidget);
      expect(find.text('· 3 из 7 дней с чтением'), findsOneWidget);
    });

    testWidgets('formats hours and minutes when total >= 60', (tester) async {
      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 22), minutes: 65),
          ReadingTrendDay(date: DateTime(2026, 7, 23), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 24), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 25), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 28), minutes: 0),
        ]),
      );

      expect(find.text('1 ч 5 мин'), findsOneWidget);
    });

    testWidgets('formats exact hours when total is multiple of 60', (tester) async {
      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 22), minutes: 120),
          ReadingTrendDay(date: DateTime(2026, 7, 23), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 24), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 25), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 28), minutes: 0),
        ]),
      );

      expect(find.text('2 ч'), findsOneWidget);
    });

    testWidgets('shows zero days with grey bars and reading days with primary bars', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 28), minutes: 30),
        ]),
      );

      final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final decorations = decoratedBoxes
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .toList();

      final primaryBars = decorations.where(
        (d) =>
            d.color == Theme.of(tester.element(find.byType(ReadingTrendChart))).colorScheme.primary,
      );
      final greyBars = decorations.where(
        (d) =>
            d.color ==
            Theme.of(
              tester.element(find.byType(ReadingTrendChart)),
            ).colorScheme.surfaceContainerHighest,
      );

      expect(primaryBars.length, 1);
      expect(greyBars.length, 1);
    });

    testWidgets('shows zero minutes summary when no reading days', (tester) async {
      await tester.pumpWidget(
        buildChart([
          ReadingTrendDay(date: DateTime(2026, 7, 22), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 23), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 24), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 25), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 0),
          ReadingTrendDay(date: DateTime(2026, 7, 28), minutes: 0),
        ]),
      );

      expect(find.text('0 мин'), findsOneWidget);
      expect(find.text('· 0 из 7 дней с чтением'), findsOneWidget);
    });
  });
}

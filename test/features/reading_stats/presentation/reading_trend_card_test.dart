import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_stats/data/reading_trend.dart';
import 'package:glibusta/features/reading_stats/presentation/reading_trend_card.dart';

void main() {
  testWidgets('summarises a local reading trend with one accessible label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingTrendChart(
            trend: [
              ReadingTrendDay(date: DateTime(2026, 7, 26), minutes: 0),
              ReadingTrendDay(date: DateTime(2026, 7, 27), minutes: 20),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1 из 2 дней с чтением'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ReadingTrendChart)),
      matchesSemantics(
        label: 'Ритм чтения: 1 активный день, 20 минут за выбранный период',
      ),
    );
    semantics.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reading_goals/data/reading_goal_repository.dart';
import 'package:glibusta/features/reading_goals/presentation/reading_goal_dialog.dart';
import 'package:glibusta/features/reading_goals/presentation/reading_goal_provider.dart';

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        readingGoalProvider.overrideWithValue(
          const AsyncData(ReadingGoal(isEnabled: true)),
        ),
      ],
      child: const MaterialApp(home: ReadingGoalDialog()),
    );
  }

  group('ReadingGoalDialog', () {
    testWidgets('renders dialog with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Цель чтения'), findsOneWidget);
    });

    testWidgets('shows enable toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Включить цель'), findsOneWidget);
    });

    testWidgets('shows slider when enabled', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('has save and cancel buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Сохранить'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
    });
  });
}

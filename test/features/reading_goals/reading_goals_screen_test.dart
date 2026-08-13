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
    testWidgets('waits for the stored goal before exposing editable controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [readingGoalProvider.overrideWithValue(const AsyncLoading())],
          child: const MaterialApp(home: ReadingGoalDialog()),
        ),
      );
      await tester.pump();

      expect(find.text('Загружаем настройки…'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Сохранить'), findsNothing);
    });

    testWidgets('offers a retry when the stored goal cannot be loaded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readingGoalProvider.overrideWithValue(
              AsyncError(StateError('preferences unavailable'), StackTrace.empty),
            ),
          ],
          child: const MaterialApp(home: ReadingGoalDialog()),
        ),
      );
      await tester.pump();

      expect(find.text('Не удалось загрузить настройки цели.'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

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

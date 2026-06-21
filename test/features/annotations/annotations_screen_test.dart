import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/annotations/data/annotations_providers.dart';
import 'package:glibusta/features/annotations/presentation/annotations_screen.dart';

void main() {
  Widget buildTestWidget({String? bookId}) {
    return ProviderScope(
      overrides: [
        allAnnotationsProvider(bookId).overrideWithValue(
          const AsyncData(
            AnnotationData(bookmarks: [], notes: [], quotes: []),
          ),
        ),
      ],
      child: MaterialApp(
        home: AnnotationsScreen(bookId: bookId),
      ),
    );
  }

  group('AnnotationsScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Аннотации'), findsOneWidget);
    });

    testWidgets('shows tab bar with three tabs', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Закладки'), findsOneWidget);
      expect(find.text('Заметки'), findsOneWidget);
      expect(find.text('Цитаты'), findsOneWidget);
    });

    testWidgets('shows empty state for bookmarks tab', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Нет закладок'), findsOneWidget);
    });

    testWidgets('switches to notes tab', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      expect(find.text('Нет заметок'), findsOneWidget);
    });

    testWidgets('switches to quotes tab', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Цитаты'));
      await tester.pumpAndSettle();

      expect(find.text('Нет цитат'), findsOneWidget);
    });
  });
}

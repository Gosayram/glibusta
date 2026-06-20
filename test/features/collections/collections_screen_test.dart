import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/collections/presentation/collections_screen.dart';
import 'package:glibusta/features/collections/presentation/smart_collections_provider.dart';

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        userCollectionsProvider.overrideWithValue(const AsyncData([])),
        smartCollectionsProvider.overrideWithValue(
          const AsyncData([
            SmartCollection(type: SmartCollectionType.reading, books: []),
            SmartCollection(type: SmartCollectionType.toRead, books: []),
          ]),
        ),
      ],
      child: const MaterialApp(
        home: CollectionsScreen(),
      ),
    );
  }

  group('CollectionsScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Коллекции'), findsOneWidget);
    });

    testWidgets('shows "Мои коллекции" section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Мои коллекции'), findsOneWidget);
    });

    testWidgets('shows "Автоматические" section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Автоматические'), findsOneWidget);
    });

    testWidgets('shows create collection prompt when empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Создать коллекцию'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('has floating action button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/presentation/library_screen.dart';

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        libraryBooksProvider.overrideWithValue(const AsyncData([])),
      ],
      child: const MaterialApp(home: LibraryScreen()),
    );
  }

  group('LibraryScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Библиотека'), findsOneWidget);
    });

    testWidgets('shows empty state when no books', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Библиотека пуста'), findsOneWidget);
    });

    testWidgets('shows import buttons when empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Перейти в каталог'), findsOneWidget);
      expect(find.text('Импортировать файл'), findsOneWidget);
    });

    testWidgets('has search button in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}

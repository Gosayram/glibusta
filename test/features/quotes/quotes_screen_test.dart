import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/quotes/data/quotes_providers.dart';
import 'package:glibusta/features/quotes/presentation/quotes_screen.dart';

void main() {
  Widget buildTestWidget({String bookId = 'test-book-id'}) {
    return ProviderScope(
      overrides: [
        quotesStreamProvider(bookId).overrideWithValue(
          const AsyncData([]),
        ),
      ],
      child: MaterialApp(
        home: QuotesScreen(bookId: bookId),
      ),
    );
  }

  group('QuotesScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Цитаты'), findsOneWidget);
    });

    testWidgets('shows empty state when no quotes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Нет цитат'), findsOneWidget);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
    });

    testWidgets('shows button to open library', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Открыть библиотеку'), findsOneWidget);
    });
  });
}

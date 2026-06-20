import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/bookmarks/data/bookmarks_providers.dart';
import 'package:glibusta/features/bookmarks/presentation/bookmarks_screen.dart';

void main() {
  Widget buildTestWidget({String bookId = 'test-book-id'}) {
    return ProviderScope(
      overrides: [
        bookmarksStreamProvider(bookId).overrideWithValue(
          const AsyncData([]),
        ),
      ],
      child: MaterialApp(
        home: BookmarksScreen(bookId: bookId),
      ),
    );
  }

  group('BookmarksScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Закладки'), findsOneWidget);
    });

    testWidgets('shows empty state when no bookmarks', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Нет закладок'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('shows button to open library', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Открыть библиотеку'), findsOneWidget);
    });
  });
}

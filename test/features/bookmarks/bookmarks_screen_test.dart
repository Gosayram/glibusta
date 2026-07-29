import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/bookmarks/data/bookmarks_providers.dart';
import 'package:glibusta/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:go_router/go_router.dart';

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

    testWidgets('opens a bookmark at its saved semantic position', (tester) async {
      const bookId = 'book-id';
      final bookmark = Bookmark(
        id: 'bookmark-id',
        bookId: bookId,
        chapterIndex: 2,
        paragraphIndex: 7,
        localOffset: 0.42,
        createdAt: DateTime(2026),
      );
      ReaderPosition? receivedPosition;
      final router = GoRouter(
        initialLocation: '/bookmarks/$bookId',
        routes: [
          GoRoute(
            path: '/bookmarks/:bookId',
            builder: (_, _) => ProviderScope(
              overrides: [
                bookmarksStreamProvider(bookId).overrideWithValue(AsyncData([bookmark])),
              ],
              child: const BookmarksScreen(bookId: bookId),
            ),
          ),
          GoRoute(
            path: '/reader/:bookId',
            builder: (_, state) {
              receivedPosition = state.extra as ReaderPosition?;
              return const Scaffold(body: Text('Reader'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookmark-id')));
      await tester.pumpAndSettle();

      expect(find.text('Reader'), findsOneWidget);
      expect(receivedPosition, isNotNull);
      expect(receivedPosition!.chapterIndex, 2);
      expect(receivedPosition!.paragraphIndex, 7);
      expect(receivedPosition!.localOffset, 42);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/bookmarks/data/bookmarks_providers.dart';
import 'package:glibusta/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestWidget({String bookId = 'test-book-id', List<Bookmark> bookmarks = const []}) {
    return ProviderScope(
      overrides: [
        bookmarksStreamProvider(bookId).overrideWithValue(
          AsyncData(bookmarks),
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

    testWidgets('filters saved bookmarks by selected text or note without changing them', (
      tester,
    ) async {
      final bookmarks = [
        Bookmark(
          id: 'bookmark-quote',
          bookId: 'test-book-id',
          chapterIndex: 0,
          paragraphIndex: 0,
          localOffset: 0,
          selectedText: 'Старый фрагмент',
          createdAt: DateTime(2026),
        ),
        Bookmark(
          id: 'bookmark-note',
          bookId: 'test-book-id',
          chapterIndex: 1,
          paragraphIndex: 2,
          localOffset: 0,
          selectedText: 'Другой фрагмент',
          note: 'Важная мысль',
          createdAt: DateTime(2026),
        ),
      ];
      await tester.pumpWidget(buildTestWidget(bookmarks: bookmarks));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Поиск закладок'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'ВАЖНАЯ');
      await tester.pump();

      expect(find.text('Другой фрагмент'), findsOneWidget);
      expect(find.text('Важная мысль'), findsOneWidget);
      expect(find.text('Старый фрагмент'), findsNothing);

      await tester.enterText(find.byType(TextField), 'нет совпадений');
      await tester.pump();
      expect(find.text('Ничего не найдено'), findsOneWidget);
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

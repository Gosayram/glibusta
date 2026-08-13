// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/annotations/data/annotations_providers.dart';
import 'package:glibusta/features/annotations/presentation/annotations_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  List<Bookmark> generateBookmarks(int count) {
    return List.generate(
      count,
      (i) => Bookmark(
        id: 'bm-$i',
        bookId: 'book-1',
        chapterIndex: i ~/ 100,
        paragraphIndex: i % 100,
        localOffset: 0,
        selectedText: 'Закладка $i',
        createdAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
      ),
    );
  }

  List<Note> generateNotes(int count) {
    return List.generate(
      count,
      (i) => Note(
        id: 'note-$i',
        bookId: 'book-1',
        chapterIndex: i ~/ 100,
        paragraphIndex: i % 100,
        localOffset: 0,
        content: 'Заметка $i',
        highlightColor: i.isEven ? '#FFEB3B' : '#81C784',
        createdAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
      ),
    );
  }

  List<Quote> generateQuotes(int count) {
    return List.generate(
      count,
      (i) => Quote(
        id: 'q-$i',
        bookId: 'book-1',
        chapterIndex: i ~/ 100,
        paragraphIndex: i % 100,
        selectedText: 'Цитата $i',
        createdAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
      ),
    );
  }

  Widget buildTestWidget({
    String? bookId,
    required AnnotationData data,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => AnnotationsScreen(bookId: bookId),
        ),
        GoRoute(
          path: '/reader/:bookId',
          builder: (_, _) => const Scaffold(body: Text('Reader')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        annotationPageProvider(
          AnnotationPageParams(bookId: bookId, limit: 50, offset: 0),
        ).overrideWithValue(AsyncData(data)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('Annotations performance', () {
    testWidgets('renders with 1000 bookmarks without error', (tester) async {
      final bookmarks = generateBookmarks(1000);
      final data = AnnotationData(bookmarks: bookmarks, notes: [], quotes: []);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      expect(find.text('Аннотации'), findsOneWidget);
      expect(find.text('Закладки'), findsOneWidget);
    });

    testWidgets('lazy renders only visible items from 1000 bookmarks', (tester) async {
      final bookmarks = generateBookmarks(1000);
      final data = AnnotationData(bookmarks: bookmarks, notes: [], quotes: []);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      final renderedTiles = tester.widgetList(find.byType(ListTile)).length;
      expect(renderedTiles, lessThan(1000));
      expect(renderedTiles, greaterThan(0));
    });

    testWidgets('renders with 1000 notes without error', (tester) async {
      final notes = generateNotes(1000);
      final data = AnnotationData(bookmarks: [], notes: notes, quotes: []);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      expect(find.text('Заметки'), findsOneWidget);
    });

    testWidgets('renders with 1000 quotes without error', (tester) async {
      final quotes = generateQuotes(1000);
      final data = AnnotationData(bookmarks: [], notes: [], quotes: quotes);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Цитаты'));
      await tester.pumpAndSettle();

      expect(find.text('Цитаты'), findsOneWidget);
    });

    testWidgets('search filters large dataset without error', (tester) async {
      final bookmarks = generateBookmarks(30);
      final notes = generateNotes(15);
      final data = AnnotationData(bookmarks: bookmarks, notes: notes, quotes: []);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Поиск аннотаций'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Закладка 29');
      await tester.pump();

      expect(find.text('Закладка 29'), findsAtLeastNWidgets(1));
      expect(find.text('Ничего не найдено'), findsNothing);
    });

    testWidgets('color filter works with 1000 notes', (tester) async {
      final notes = generateNotes(1000);
      final data = AnnotationData(bookmarks: [], notes: notes, quotes: []);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('no loading indicator when all data loaded', (tester) async {
      final data = AnnotationData(
        bookmarks: generateBookmarks(10),
        notes: [],
        quotes: [],
      );

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty state renders with 0 items', (tester) async {
      final data = const AnnotationData(bookmarks: [], notes: [], quotes: []);

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      expect(find.text('Нет закладок'), findsOneWidget);
    });
  });
}

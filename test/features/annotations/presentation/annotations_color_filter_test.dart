import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/annotations/data/annotations_providers.dart';
import 'package:glibusta/features/annotations/presentation/annotations_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestWidget({
    String? bookId,
    AnnotationData? data,
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
        allAnnotationsProvider(bookId).overrideWithValue(
          AsyncData(data ?? const AnnotationData(bookmarks: [], notes: [], quotes: [])),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Note makeNote(String id, String color, {String content = 'Заметка'}) => Note(
    id: id,
    bookId: 'book-1',
    chapterIndex: 0,
    paragraphIndex: 0,
    localOffset: 0,
    content: content,
    highlightColor: color,
    createdAt: DateTime(2026),
  );

  group('Color filter', () {
    testWidgets('shows color circles when notes have multiple colors', (tester) async {
      final data = AnnotationData(
        bookmarks: [],
        notes: [
          makeNote('n1', '#FFEB3B', content: 'Жёлтая'),
          makeNote('n2', '#81C784', content: 'Зелёная'),
          makeNote('n3', '#90CAF9', content: 'Синяя'),
        ],
        quotes: [],
      );

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsWidgets);
      expect(find.text('Жёлтая'), findsOneWidget);
      expect(find.text('Зелёная'), findsOneWidget);
      expect(find.text('Синяя'), findsOneWidget);
    });

    testWidgets('selecting a color filters the notes list', (tester) async {
      final data = AnnotationData(
        bookmarks: [],
        notes: [
          makeNote('n1', '#FFEB3B', content: 'Жёлтая заметка'),
          makeNote('n2', '#81C784', content: 'Зелёная заметка'),
          makeNote('n3', '#FFEB3B', content: 'Ещё жёлтая'),
        ],
        quotes: [],
      );

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      expect(find.text('Жёлтая заметка'), findsOneWidget);
      expect(find.text('Зелёная заметка'), findsOneWidget);
      expect(find.text('Ещё жёлтая'), findsOneWidget);

      final circles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      expect(circles, findsNWidgets(2));

      await tester.tap(circles.first);
      await tester.pumpAndSettle();

      expect(find.text('Жёлтая заметка'), findsOneWidget);
      expect(find.text('Ещё жёлтая'), findsOneWidget);
      expect(find.text('Зелёная заметка'), findsNothing);
    });

    testWidgets('deselecting color shows all notes again', (tester) async {
      final data = AnnotationData(
        bookmarks: [],
        notes: [
          makeNote('n1', '#FFEB3B', content: 'Жёлтая'),
          makeNote('n2', '#81C784', content: 'Зелёная'),
        ],
        quotes: [],
      );

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      final circles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );

      await tester.tap(circles.first);
      await tester.pumpAndSettle();
      expect(find.text('Зелёная'), findsNothing);

      await tester.tap(circles.first);
      await tester.pumpAndSettle();
      expect(find.text('Жёлтая'), findsOneWidget);
      expect(find.text('Зелёная'), findsOneWidget);
    });

    testWidgets('color filter works together with search query', (tester) async {
      final data = AnnotationData(
        bookmarks: [],
        notes: [
          makeNote('n1', '#FFEB3B', content: 'Важная жёлтая заметка'),
          makeNote('n2', '#81C784', content: 'Важная зелёная заметка'),
          makeNote('n3', '#FFEB3B', content: 'Другая жёлтая'),
        ],
        quotes: [],
      );

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Поиск аннотаций'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Важная');
      await tester.pump();

      expect(find.text('Важная жёлтая заметка'), findsOneWidget);
      expect(find.text('Важная зелёная заметка'), findsOneWidget);
      expect(find.text('Другая жёлтая'), findsNothing);

      final circles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      await tester.tap(circles.first);
      await tester.pumpAndSettle();

      expect(find.text('Важная жёлтая заметка'), findsOneWidget);
      expect(find.text('Важная зелёная заметка'), findsNothing);
      expect(find.text('Другая жёлтая'), findsNothing);
    });

    testWidgets('color filter does not affect bookmarks or quotes', (tester) async {
      final data = AnnotationData(
        bookmarks: [
          Bookmark(
            id: 'b1',
            bookId: 'book-1',
            chapterIndex: 0,
            paragraphIndex: 0,
            localOffset: 0,
            selectedText: 'Закладка',
            createdAt: DateTime(2026),
          ),
        ],
        notes: [
          makeNote('n1', '#FFEB3B', content: 'Жёлтая'),
          makeNote('n2', '#81C784', content: 'Зелёная'),
        ],
        quotes: [
          Quote(
            id: 'q1',
            bookId: 'book-1',
            chapterIndex: 0,
            paragraphIndex: 0,
            selectedText: 'Цитата',
            createdAt: DateTime(2026),
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      expect(find.text('Закладка'), findsOneWidget);

      await tester.tap(find.text('Цитаты'));
      await tester.pumpAndSettle();
      expect(find.text('Цитата'), findsOneWidget);
    });
  });
}

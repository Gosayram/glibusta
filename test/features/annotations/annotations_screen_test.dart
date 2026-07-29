import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/annotations/data/annotations_providers.dart';
import 'package:glibusta/features/annotations/presentation/annotations_screen.dart';

void main() {
  Widget buildTestWidget({String? bookId, AnnotationData? data}) {
    return ProviderScope(
      overrides: [
        allAnnotationsProvider(bookId).overrideWithValue(
          AsyncData(data ?? const AnnotationData(bookmarks: [], notes: [], quotes: [])),
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

    testWidgets('filters every annotation type by a case-insensitive local query', (tester) async {
      final data = AnnotationData(
        bookmarks: [
          Bookmark(
            id: 'bookmark-1',
            bookId: 'book-1',
            chapterIndex: 0,
            paragraphIndex: 0,
            localOffset: 0,
            selectedText: 'Первый фрагмент',
            createdAt: DateTime(2026),
          ),
        ],
        notes: [
          Note(
            id: 'note-1',
            bookId: 'book-1',
            chapterIndex: 0,
            paragraphIndex: 0,
            localOffset: 0,
            content: 'Ночная заметка',
            highlightColor: '#FFEB3B',
            createdAt: DateTime(2026),
          ),
        ],
        quotes: [
          Quote(
            id: 'quote-1',
            bookId: 'book-1',
            chapterIndex: 0,
            paragraphIndex: 0,
            selectedText: 'Редкая цитата',
            note: 'Важно сохранить',
            createdAt: DateTime(2026),
          ),
        ],
      );
      await tester.pumpWidget(buildTestWidget(data: data));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Поиск аннотаций'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'ПЕРВЫЙ');
      await tester.pump();

      expect(find.text('Первый фрагмент'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'НОЧНАЯ');
      await tester.pump();

      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.tap(find.text('Заметки'));
      await tester.pumpAndSettle();
      expect(find.text('Ночная заметка'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'важно');
      await tester.pump();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.tap(find.text('Цитаты'));
      await tester.pumpAndSettle();
      expect(find.text('Редкая цитата'), findsOneWidget);
    });
  });
}

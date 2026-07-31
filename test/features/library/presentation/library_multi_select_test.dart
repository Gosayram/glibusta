import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/presentation/library_screen.dart';
import 'package:glibusta/shared/models/book.dart';

List<Book> _testBooks() => [
  const Book(
    id: 'book-1',
    title: 'Первая книга',
    authorIds: ['a1'],
    authorNames: ['Автор Один'],
    genreIds: [],
    description: null,
    coverUrl: null,
    publishDate: null,
    availableFormats: [BookFormat.epub],
    source: BookSourceInfo(sourceId: 'local', sourceUrl: ''),
  ),
  const Book(
    id: 'book-2',
    title: 'Вторая книга',
    authorIds: ['a2'],
    authorNames: ['Автор Два'],
    genreIds: [],
    description: null,
    coverUrl: null,
    publishDate: null,
    availableFormats: [BookFormat.fb2],
    source: BookSourceInfo(sourceId: 'local', sourceUrl: ''),
  ),
  const Book(
    id: 'book-3',
    title: 'Третья книга',
    authorIds: ['a3'],
    authorNames: ['Автор Три'],
    genreIds: [],
    description: null,
    coverUrl: null,
    publishDate: null,
    availableFormats: [BookFormat.txt],
    source: BookSourceInfo(sourceId: 'local', sourceUrl: ''),
  ),
];

Widget _buildTestWidget(List<Book> books) {
  return ProviderScope(
    overrides: [
      libraryBooksProvider.overrideWithValue(AsyncData(books)),
    ],
    child: const MaterialApp(home: LibraryScreen()),
  );
}

void main() {
  group('Library multi-select', () {
    testWidgets('long-press enters selection mode', (tester) async {
      final books = _testBooks();
      await tester.pumpWidget(_buildTestWidget(books));
      await tester.pumpAndSettle();

      expect(find.text('Библиотека'), findsOneWidget);

      await tester.longPress(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();

      expect(find.text('1 выбрано'), findsOneWidget);
    });

    testWidgets('tap toggles selection when in selection mode', (tester) async {
      final books = _testBooks();
      await tester.pumpWidget(_buildTestWidget(books));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();
      expect(find.text('1 выбрано'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('book-2')).first);
      await tester.pumpAndSettle();
      expect(find.text('2 выбрано'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();
      expect(find.text('1 выбрано'), findsOneWidget);
    });

    testWidgets('select all selects every book', (tester) async {
      final books = _testBooks();
      await tester.pumpWidget(_buildTestWidget(books));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Выбрать все'));
      await tester.pumpAndSettle();

      expect(find.text('3 выбрано'), findsOneWidget);
    });

    testWidgets('cancel exits selection mode', (tester) async {
      final books = _testBooks();
      await tester.pumpWidget(_buildTestWidget(books));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();
      expect(find.text('1 выбрано'), findsOneWidget);

      await tester.tap(find.byTooltip('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Библиотека'), findsOneWidget);
      expect(find.text('1 выбрано'), findsNothing);
    });

    testWidgets('delete button shows confirmation dialog', (tester) async {
      final books = _testBooks();
      await tester.pumpWidget(_buildTestWidget(books));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Удалить'));
      await tester.pumpAndSettle();

      expect(find.text('Удалить 1 книга?'), findsOneWidget);
      expect(find.text('Удалить'), findsWidgets);
      expect(find.text('Отмена'), findsOneWidget);
    });

    testWidgets('cancel delete dismisses dialog and stays in selection', (
      tester,
    ) async {
      final books = _testBooks();
      await tester.pumpWidget(_buildTestWidget(books));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('book-1')).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Удалить'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();

      expect(find.text('1 выбрано'), findsOneWidget);
    });
  });
}

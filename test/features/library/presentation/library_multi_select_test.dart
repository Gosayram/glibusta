import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/data/book_repository_impl.dart';
import 'package:glibusta/features/library/domain/book_repository.dart';
import 'package:glibusta/features/library/presentation/library_screen.dart';
import 'package:glibusta/shared/models/book.dart';

class _FakeBookRepository implements BookRepository {
  final List<Book> books;

  _FakeBookRepository(this.books);

  @override
  Future<List<Book>> getAllBooks() async => books;

  @override
  Future<List<Book>> getPagedBooks({
    required int limit,
    int offset = 0,
    BookSortField sortField = BookSortField.addedAt,
    bool ascending = false,
  }) async {
    final end = (offset + limit).clamp(0, books.length);
    if (offset >= books.length) return [];
    return books.sublist(offset, end);
  }

  @override
  Future<List<Book>> searchBooksPaged(
    String query, {
    required int limit,
    int offset = 0,
  }) async {
    final lower = query.toLowerCase();
    final filtered = books.where((b) => b.title.toLowerCase().contains(lower)).toList();
    final end = (offset + limit).clamp(0, filtered.length);
    if (offset >= filtered.length) return [];
    return filtered.sublist(offset, end);
  }

  @override
  Future<List<Book>> getBooksByIds(List<String> ids) async =>
      books.where((b) => ids.contains(b.id)).toList();

  @override
  Future<List<Book>> searchBooks(String query) async => books;

  @override
  Future<List<Book>> getBooksWithProgress() async => [];

  @override
  Future<Book?> getBookById(String id) async => null;

  @override
  Future<void> saveBook(Book book) async {}

  @override
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> deleteBook(String id) async {}

  @override
  Future<bool> isBookInLibrary(String id) async => false;
}

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
      bookRepositoryProvider.overrideWithValue(_FakeBookRepository(books)),
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

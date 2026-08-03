import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/data/book_repository_impl.dart';
import 'package:glibusta/features/library/domain/book_repository.dart';
import 'package:glibusta/features/library/presentation/library_screen.dart';
import 'package:glibusta/shared/models/book.dart';

class FakeBookRepository implements BookRepository {
  final List<Book> updatedBooks = [];

  @override
  Future<List<Book>> getAllBooks() async => [];

  @override
  Future<List<Book>> getPagedBooks({
    required int limit,
    int offset = 0,
    BookSortField sortField = BookSortField.addedAt,
    bool ascending = false,
    String? formatFilter,
  }) async => [];

  @override
  Future<List<Book>> searchBooksPaged(
    String query, {
    required int limit,
    int offset = 0,
    String? formatFilter,
  }) async => [];

  @override
  Future<List<Book>> getBooksByIds(List<String> ids) async => [];

  @override
  Future<List<Book>> searchBooks(String query) async => [];

  @override
  Future<List<Book>> getBooksWithProgress() async => [];

  @override
  Future<Book?> getBookById(String id) async => null;

  @override
  Future<void> saveBook(Book book) async {}

  @override
  Future<void> updateBook(Book book) async {
    updatedBooks.add(book);
  }

  @override
  Future<void> deleteBook(String id) async {}

  @override
  Future<bool> isBookInLibrary(String id) async => false;
}

Book _makeTestBook({
  String id = 'book1',
  String title = 'Тестовая книга',
  List<String> authorIds = const ['author1'],
  List<String> authorNames = const ['Иванов И.И.'],
  String? description = 'Описание книги',
}) {
  return Book(
    id: id,
    title: title,
    authorIds: authorIds,
    authorNames: authorNames,
    genreIds: const [],
    description: description,
    coverUrl: null,
    publishDate: null,
    availableFormats: const [],
    source: const BookSourceInfo(sourceId: 'test', sourceUrl: 'http://test'),
  );
}

Widget _buildSheetHarness({
  required Book book,
  required FakeBookRepository repository,
}) {
  return ProviderScope(
    overrides: [
      bookRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                unawaited(
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditMetadataSheet(book: book),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Edit metadata', () {
    testWidgets('dialog shows current book values', (tester) async {
      final book = _makeTestBook(
        title: 'Война и мир',
        authorNames: const ['Толстой Л.Н.'],
        description: 'Роман-эпопея',
      );
      final repo = FakeBookRepository();

      await tester.pumpWidget(_buildSheetHarness(book: book, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Редактировать метаданные'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Война и мир'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Толстой Л.Н.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Роман-эпопея'), findsOneWidget);
    });

    testWidgets('saving updates the book in repository', (tester) async {
      final book = _makeTestBook(title: 'Старое название');
      final repo = FakeBookRepository();

      await tester.pumpWidget(_buildSheetHarness(book: book, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final titleField = find.widgetWithText(TextFormField, 'Старое название');
      await tester.enterText(titleField, 'Новое название');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(repo.updatedBooks, hasLength(1));
      expect(repo.updatedBooks.first.title, 'Новое название');
    });

    testWidgets('empty title is rejected', (tester) async {
      final book = _makeTestBook(title: 'Книга');
      final repo = FakeBookRepository();

      await tester.pumpWidget(_buildSheetHarness(book: book, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final titleField = find.widgetWithText(TextFormField, 'Книга');
      await tester.enterText(titleField, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Введите название'), findsOneWidget);
      expect(repo.updatedBooks, isEmpty);
    });

    testWidgets('authors are parsed from comma-separated string', (tester) async {
      final book = _makeTestBook(
        title: 'Книга',
        authorNames: const ['Один автор'],
      );
      final repo = FakeBookRepository();

      await tester.pumpWidget(_buildSheetHarness(book: book, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final authorField = find.widgetWithText(TextFormField, 'Один автор');
      await tester.enterText(authorField, 'Иванов, Петров, Сидоров');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(repo.updatedBooks, hasLength(1));
      final updated = repo.updatedBooks.first;
      expect(updated.authorNames, ['Иванов', 'Петров', 'Сидоров']);
      expect(updated.authorIds, ['Иванов', 'Петров', 'Сидоров']);
    });
  });

  group('Book.copyWith', () {
    test('returns new instance with updated fields', () {
      final book = _makeTestBook(
        title: 'Original',
        authorNames: const ['Author'],
        description: 'Desc',
      );

      final updated = book.copyWith(
        title: 'Updated',
        authorNames: const ['New Author'],
      );

      expect(updated.title, 'Updated');
      expect(updated.authorNames, ['New Author']);
      expect(updated.description, 'Desc');
      expect(updated.id, book.id);
    });

    test('preserves original when no changes', () {
      final book = _makeTestBook();
      final copy = book.copyWith();

      expect(copy.title, book.title);
      expect(copy.authorIds, book.authorIds);
      expect(copy.description, book.description);
    });
  });
}

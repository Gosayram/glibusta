import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/data/book_repository_impl.dart';
import 'package:glibusta/features/library/domain/book_repository.dart';
import 'package:glibusta/features/library/presentation/library_screen.dart';
import 'package:glibusta/shared/models/book.dart';

class _FakeBookRepository implements BookRepository {
  @override
  Future<List<Book>> getAllBooks() async => [];

  @override
  Future<List<Book>> getPagedBooks({
    required int limit,
    int offset = 0,
    BookSortField sortField = BookSortField.addedAt,
    bool ascending = false,
  }) async => [];

  @override
  Future<List<Book>> searchBooksPaged(
    String query, {
    required int limit,
    int offset = 0,
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
  Future<void> updateBook(Book book) async {}

  @override
  Future<void> deleteBook(String id) async {}

  @override
  Future<bool> isBookInLibrary(String id) async => false;
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
      ],
      child: const MaterialApp(home: LibraryScreen()),
    );
  }

  group('LibraryScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Библиотека'), findsOneWidget);
    });

    testWidgets('shows empty state when no books', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Библиотека пуста'), findsOneWidget);
    });

    testWidgets('shows import buttons when empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Перейти в каталог'), findsOneWidget);
      expect(find.text('Импортировать файл'), findsOneWidget);
    });

    testWidgets('has search button in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}

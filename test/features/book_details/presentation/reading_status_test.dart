import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/book_details/presentation/book_details_providers.dart';
import 'package:glibusta/features/book_details/presentation/widgets/reading_status_selector.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({String bookId = 'b1', SavedBook? savedBook}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        savedBookProvider(bookId).overrideWithValue(
          AsyncData(savedBook),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ReadingStatusSelector(bookId: 'b1'),
        ),
      ),
    );
  }

  Future<void> insertBook({String id = 'b1', String status = 'none'}) async {
    await db.bookDao.insertBook(
      SavedBooksCompanion.insert(id: id, title: 'Test Book'),
    );
    if (status != 'none') {
      await db.bookDao.updateReadingStatus(id, status);
    }
  }

  group('ReadingStatusSelector', () {
    testWidgets('renders all three status options', (tester) async {
      await insertBook();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Читаю'), findsOneWidget);
      expect(find.text('Хочу прочитать'), findsOneWidget);
      expect(find.text('Прочитано'), findsOneWidget);
    });

    testWidgets('shows section label', (tester) async {
      await insertBook();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Статус чтения'), findsOneWidget);
    });

    testWidgets('highlights current status when reading', (tester) async {
      await insertBook(status: 'reading');
      final book = await db.bookDao.getBookById('b1');

      await tester.pumpWidget(buildTestWidget(savedBook: book));
      await tester.pumpAndSettle();

      // The "Читаю" chip should be rendered with the selected style
      expect(find.text('Читаю'), findsOneWidget);
    });

    testWidgets('tapping status updates database', (tester) async {
      await insertBook();
      final book = await db.bookDao.getBookById('b1');

      await tester.pumpWidget(buildTestWidget(savedBook: book));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Читаю'));
      await tester.pumpAndSettle();

      final updated = await db.bookDao.getBookById('b1');
      expect(updated!.readingStatus, ReadingStatus.reading.name);
    });

    testWidgets('tapping finished updates database', (tester) async {
      await insertBook();
      final book = await db.bookDao.getBookById('b1');

      await tester.pumpWidget(buildTestWidget(savedBook: book));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Прочитано'));
      await tester.pumpAndSettle();

      final updated = await db.bookDao.getBookById('b1');
      expect(updated!.readingStatus, ReadingStatus.finished.name);
    });

    testWidgets('tapping wantToRead updates database', (tester) async {
      await insertBook();
      final book = await db.bookDao.getBookById('b1');

      await tester.pumpWidget(buildTestWidget(savedBook: book));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Хочу прочитать'));
      await tester.pumpAndSettle();

      final updated = await db.bookDao.getBookById('b1');
      expect(updated!.readingStatus, ReadingStatus.wantToRead.name);
    });
  });
}

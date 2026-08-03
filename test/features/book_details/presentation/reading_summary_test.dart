import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/book_details/presentation/book_details_providers.dart';
import 'package:glibusta/features/book_details/presentation/widgets/reading_summary_card.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({String bookId = 'b1', int totalSeconds = 0}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        bookReadingProgressProvider(bookId).overrideWithValue(
          const AsyncData(null),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ReadingSummaryCard(bookId: 'b1'),
        ),
      ),
    );
  }

  Future<void> insertProgress({
    String bookId = 'b1',
    double progress = 0.5,
    int chapterIndex = 2,
    int totalPages = 100,
    DateTime? lastRead,
  }) async {
    await db.bookDao.upsertReadingProgress(
      ReadingProgressCompanion.insert(
        bookId: bookId,
        progressPercent: Value(progress),
        chapterIndex: Value(chapterIndex),
        totalPages: Value(totalPages),
        lastRead: Value(lastRead ?? DateTime.now()),
      ),
    );
  }

  group('ReadingSummaryCard', () {
    testWidgets('hides when no reading progress exists', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Прогресс чтения'), findsNothing);
    });

    testWidgets('shows progress percentage when data exists', (tester) async {
      await insertProgress(progress: 0.42);
      final progress = await db.bookDao.getReadingProgress('b1');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          bookReadingProgressProvider('b1').overrideWithValue(
            AsyncData(progress),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ReadingSummaryCard(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Прогресс чтения'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('formats minutes correctly', (tester) async {
      // Insert progress and reading time directly
      await insertProgress(progress: 0.1, chapterIndex: 0);
      await db.readingTimeDao.addReadingTime('b1', DateTime.now(), 120);

      final progress = await db.bookDao.getReadingProgress('b1');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          bookReadingProgressProvider('b1').overrideWithValue(
            AsyncData(progress),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ReadingSummaryCard(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 120 seconds = 2 minutes
      expect(find.text('2 мин'), findsOneWidget);
    });

    testWidgets('formats hours correctly', (tester) async {
      await insertProgress(progress: 0.3, chapterIndex: 1);
      await db.readingTimeDao.addReadingTime('b1', DateTime.now(), 7200);

      final progress = await db.bookDao.getReadingProgress('b1');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          bookReadingProgressProvider('b1').overrideWithValue(
            AsyncData(progress),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ReadingSummaryCard(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 7200 seconds = 2 hours
      expect(find.text('2 ч '), findsOneWidget);
    });

    testWidgets('shows last read relative date', (tester) async {
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      await insertProgress(progress: 0.8, lastRead: twoHoursAgo);

      final progress = await db.bookDao.getReadingProgress('b1');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          bookReadingProgressProvider('b1').overrideWithValue(
            AsyncData(progress),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ReadingSummaryCard(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 ч назад'), findsOneWidget);
    });
  });
}

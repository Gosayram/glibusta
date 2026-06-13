import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('BookDao', () {
    test('insertBook and getAllBooks', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      final books = await db.bookDao.getAllBooks();
      expect(books.length, 2);
    });

    test('getBookById returns correct book', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      final book = await db.bookDao.getBookById('b1');
      expect(book, isNotNull);
      expect(book!.title, 'Book 1');
    });

    test('getBookById returns null for missing book', () async {
      final book = await db.bookDao.getBookById('nonexistent');
      expect(book, isNull);
    });

    test('deleteBook removes book', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.deleteBook('b1');
      final book = await db.bookDao.getBookById('b1');
      expect(book, isNull);
    });

    test('updateReadingStatus changes status', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.updateReadingStatus('b1', 'reading');
      final book = await db.bookDao.getBookById('b1');
      expect(book!.readingStatus, 'reading');
    });

    test('upsertReadingProgress creates and updates', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.upsertReadingProgress(
        ReadingProgressCompanion.insert(bookId: 'b1'),
      );
      final progress = await db.bookDao.getReadingProgress('b1');
      expect(progress, isNotNull);
      expect(progress!.bookId, 'b1');

      await db.bookDao.upsertReadingProgress(
        const ReadingProgressCompanion(
          bookId: Value('b1'),
          chapterIndex: Value(5),
        ),
      );
      final updated = await db.bookDao.getReadingProgress('b1');
      expect(updated!.chapterIndex, 5);
    });

    test('deleteReadingProgress removes progress', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.upsertReadingProgress(
        ReadingProgressCompanion.insert(bookId: 'b1'),
      );
      await db.bookDao.deleteReadingProgress('b1');
      final progress = await db.bookDao.getReadingProgress('b1');
      expect(progress, isNull);
    });

    test('getBooksWithProgress returns only books with progress', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      await db.bookDao.upsertReadingProgress(
        ReadingProgressCompanion(
          bookId: const Value('b1'),
          lastRead: Value(DateTime(2024)),
        ),
      );
      final books = await db.bookDao.getBooksWithProgress();
      expect(books.length, 1);
      expect(books.first.id, 'b1');
    });

    test('startSession and endSession', () async {
      final sessionId = await db.bookDao.startSession('b1');
      expect(sessionId, greaterThan(0));
      await db.bookDao.endSession(sessionId, chaptersRead: 3);

      final sessions = await db.bookDao.getSessionsForDateRange(
        DateTime.now().subtract(const Duration(hours: 1)),
        DateTime.now().add(const Duration(hours: 1)),
      );
      expect(sessions.length, 1);
      expect(sessions.first.chaptersRead, 3);
      expect(sessions.first.endedAt, isNotNull);
    });

    test('getSessionsForDateRange filters correctly', () async {
      await db.bookDao.startSession('b1');
      final sessions = await db.bookDao.getSessionsForDateRange(
        DateTime.now().add(const Duration(days: 10)),
        DateTime.now().add(const Duration(days: 11)),
      );
      expect(sessions, isEmpty);
    });
  });
}

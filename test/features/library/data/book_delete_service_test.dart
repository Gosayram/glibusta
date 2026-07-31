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

  group('Soft delete', () {
    test('softDeleteBook sets deletedAt instead of removing row', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );

      await db.bookDao.softDeleteBook('b1');

      final book = await db.bookDao.getBookById('b1');
      expect(book, isNotNull);
      expect(book!.deletedAt, isNotNull);
      expect(book.title, 'Book 1');
    });

    test('restoreBook clears deletedAt', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.softDeleteBook('b1');

      await db.bookDao.restoreBook('b1');

      final book = await db.bookDao.getBookById('b1');
      expect(book, isNotNull);
      expect(book!.deletedAt, isNull);
    });

    test('getAllBooks excludes soft-deleted books', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      await db.bookDao.softDeleteBook('b1');

      final books = await db.bookDao.getAllBooks();
      expect(books.length, 1);
      expect(books.first.id, 'b2');
    });

    test('getDeletedBooks returns only soft-deleted books', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      await db.bookDao.softDeleteBook('b1');

      final deleted = await db.bookDao.getDeletedBooks();
      expect(deleted.length, 1);
      expect(deleted.first.id, 'b1');
    });

    test('purgeDeletedBooks permanently removes soft-deleted books', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      await db.bookDao.softDeleteBook('b1');

      await db.bookDao.purgeDeletedBooks();

      final all = await db.bookDao.getAllBooks();
      expect(all.length, 1);
      expect(all.first.id, 'b2');

      final book = await db.bookDao.getBookById('b1');
      expect(book, isNull);
    });

    test('restore after purge does nothing', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.softDeleteBook('b1');
      await db.bookDao.purgeDeletedBooks();

      final updated = await db.bookDao.restoreBook('b1');
      expect(updated, 0);

      final book = await db.bookDao.getBookById('b1');
      expect(book, isNull);
    });
  });
}

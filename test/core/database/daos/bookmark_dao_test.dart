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

  group('BookmarkDao', () {
    test('getBookmarksForBook returns bookmarks', () async {
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk1',
              bookId: 'b1',
              chapterIndex: 1,
              paragraphIndex: 0,
            ),
          );
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk2',
              bookId: 'b1',
              chapterIndex: 5,
              paragraphIndex: 2,
            ),
          );
      final bookmarks = await db.bookmarkDao.getBookmarksForBook('b1');
      expect(bookmarks.length, 2);
    });

    test('getBookmarksForBook returns empty for no bookmarks', () async {
      final bookmarks = await db.bookmarkDao.getBookmarksForBook('missing');
      expect(bookmarks, isEmpty);
    });

    test('getBookmarksForBook filters by bookId', () async {
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk1',
              bookId: 'b1',
              chapterIndex: 1,
              paragraphIndex: 0,
            ),
          );
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk2',
              bookId: 'b2',
              chapterIndex: 1,
              paragraphIndex: 0,
            ),
          );
      final bookmarks = await db.bookmarkDao.getBookmarksForBook('b1');
      expect(bookmarks.length, 1);
    });

    test('getQuotesForBook returns quotes', () async {
      await db
          .into(db.quotes)
          .insert(
            QuotesCompanion.insert(
              id: 'q1',
              bookId: 'b1',
              chapterIndex: 1,
              paragraphIndex: 0,
              selectedText: 'Hello world',
            ),
          );
      await db
          .into(db.quotes)
          .insert(
            QuotesCompanion.insert(
              id: 'q2',
              bookId: 'b1',
              chapterIndex: 2,
              paragraphIndex: 0,
              selectedText: 'Another quote',
            ),
          );
      final quotes = await db.bookmarkDao.getQuotesForBook('b1');
      expect(quotes.length, 2);
      expect(quotes.first.selectedText, 'Hello world');
    });

    test('getQuotesForBook returns empty for no quotes', () async {
      final quotes = await db.bookmarkDao.getQuotesForBook('missing');
      expect(quotes, isEmpty);
    });
  });
}

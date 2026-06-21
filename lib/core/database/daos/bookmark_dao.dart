import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [Bookmarks, Notes, Quotes])
class BookmarkDao extends DatabaseAccessor<AppDatabase> with _$BookmarkDaoMixin {
  BookmarkDao(super.attachedDatabase);

  Future<List<Bookmark>> getBookmarksForBook(String bookId) async =>
      (select(bookmarks)..where((t) => t.bookId.equals(bookId))).get();

  Stream<List<Bookmark>> watchBookmarksForBook(String bookId) =>
      (select(bookmarks)..where((t) => t.bookId.equals(bookId))).watch();

  Future<List<Quote>> getQuotesForBook(String bookId) async =>
      (select(quotes)..where((t) => t.bookId.equals(bookId))).get();

  Stream<List<Quote>> watchQuotesForBook(String bookId) =>
      (select(quotes)..where((t) => t.bookId.equals(bookId))).watch();
}

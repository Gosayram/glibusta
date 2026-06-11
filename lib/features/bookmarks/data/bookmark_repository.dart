import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class BookmarkRepository {
  final AppDatabase _db;

  BookmarkRepository(this._db);

  Future<List<Bookmark>> getAllBookmarks(String bookId) async {
    return (_db.select(_db.bookmarks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
        .get();
  }

  Future<Bookmark?> getBookmark(String id) async {
    return (_db.select(_db.bookmarks)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<int> createBookmark({
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    double localOffset = 0.0,
    String? selectedText,
    String? note,
  }) async {
    return _db
        .into(_db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            bookId: bookId,
            chapterIndex: chapterIndex,
            paragraphIndex: paragraphIndex,
            localOffset: Value(localOffset),
            selectedText: Value(selectedText),
            note: Value(note),
          ),
        );
  }

  Future<bool> updateBookmark({
    required String id,
    String? note,
    String? selectedText,
  }) async {
    final count = await (_db.update(_db.bookmarks)..where((b) => b.id.equals(id))).write(
      BookmarksCompanion(
        note: Value(note),
        selectedText: Value(selectedText),
      ),
    );
    return count > 0;
  }

  Future<int> deleteBookmark(String id) async {
    return (_db.delete(_db.bookmarks)..where((b) => b.id.equals(id))).go();
  }

  Future<void> insertBookmark(Bookmark bookmark) async {
    await _db
        .into(_db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: bookmark.id,
            bookId: bookmark.bookId,
            chapterIndex: bookmark.chapterIndex,
            paragraphIndex: bookmark.paragraphIndex,
            localOffset: Value(bookmark.localOffset),
            selectedText: Value(bookmark.selectedText),
            note: Value(bookmark.note),
          ),
        );
  }

  Stream<List<Bookmark>> watchBookmarks(String bookId) {
    return (_db.select(_db.bookmarks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
        .watch();
  }
}

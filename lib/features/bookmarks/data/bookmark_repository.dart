import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/monotonic_id.dart';

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
            id: newMonotonicId(),
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

  Future<String> exportToJson(String bookId) async {
    final bookmarks = await getAllBookmarks(bookId);
    final list = bookmarks
        .map(
          (b) => {
            'id': b.id,
            'chapterIndex': b.chapterIndex,
            'paragraphIndex': b.paragraphIndex,
            'selectedText': b.selectedText,
            'note': b.note,
            'createdAt': b.createdAt.toIso8601String(),
          },
        )
        .toList();
    // ponytail: simple JSON encode, no dependency needed
    final buf = StringBuffer('[');
    for (var i = 0; i < list.length; i++) {
      if (i > 0) buf.write(',');
      buf.write('{');
      var first = true;
      for (final e in list[i].entries) {
        if (!first) buf.write(',');
        first = false;
        buf.write('"${e.key}":');
        if (e.value == null) {
          buf.write('null');
        } else if (e.value is String) {
          buf.write('"${e.value.toString().replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"');
        } else {
          buf.write(e.value);
        }
      }
      buf.write('}');
    }
    buf.write(']');
    return buf.toString();
  }
}

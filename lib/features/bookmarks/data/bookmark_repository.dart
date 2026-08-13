import 'dart:convert';

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

  Future<List<Bookmark>> getBookmarksPage({
    String? bookId,
    required int limit,
    required int offset,
  }) {
    final query = _db.select(_db.bookmarks)
      ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])
      ..limit(limit, offset: offset);
    if (bookId != null) {
      query.where((b) => b.bookId.equals(bookId));
    }
    return query.get();
  }

  Future<int> countBookmarks({String? bookId}) async {
    final countExp = _db.bookmarks.id.count();
    final query = _db.selectOnly(_db.bookmarks)..addColumns([countExp]);
    if (bookId != null) {
      query.where(_db.bookmarks.bookId.equals(bookId));
    }
    final row = await query.getSingle();
    return row.read(countExp)!;
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
    String? highlightStyle,
    String? highlightColor,
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
            highlightStyle: Value(highlightStyle),
            highlightColor: Value(highlightColor),
          ),
        );
  }

  Future<bool> updateBookmark({
    required String id,
    String? note,
    String? selectedText,
    String? highlightStyle,
    String? highlightColor,
  }) async {
    final count = await (_db.update(_db.bookmarks)..where((b) => b.id.equals(id))).write(
      BookmarksCompanion(
        note: note != null ? Value(note) : const Value.absent(),
        selectedText: selectedText != null ? Value(selectedText) : const Value.absent(),
        highlightStyle: highlightStyle != null ? Value(highlightStyle) : const Value.absent(),
        highlightColor: highlightColor != null ? Value(highlightColor) : const Value.absent(),
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
            highlightStyle: Value(bookmark.highlightStyle),
            highlightColor: Value(bookmark.highlightColor),
          ),
          mode: InsertMode.insertOrReplace,
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
    return jsonEncode(list);
  }
}

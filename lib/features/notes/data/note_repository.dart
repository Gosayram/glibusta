import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);

  Future<List<Note>> getAllNotes(String bookId) async {
    return (_db.select(_db.notes)
          ..where((n) => n.bookId.equals(bookId))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .get();
  }

  Future<Note?> getNote(String id) async {
    return (_db.select(_db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Future<int> createNote({
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    double localOffset = 0.0,
    required String content,
    String highlightColor = '#FFEB3B',
  }) async {
    return _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            bookId: bookId,
            chapterIndex: chapterIndex,
            paragraphIndex: paragraphIndex,
            localOffset: Value(localOffset),
            content: content,
            highlightColor: Value(highlightColor),
          ),
        );
  }

  Future<bool> updateNote({
    required String id,
    String? content,
    String? highlightColor,
  }) async {
    final count = await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        content: content != null ? Value(content) : const Value.absent(),
        highlightColor: highlightColor != null ? Value(highlightColor) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return count > 0;
  }

  Future<int> deleteNote(String id) async {
    return (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
  }

  Future<void> insertNote(Note note) async {
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: note.id,
            bookId: note.bookId,
            chapterIndex: note.chapterIndex,
            paragraphIndex: note.paragraphIndex,
            content: note.content,
            highlightColor: Value(note.highlightColor),
          ),
        );
  }

  Stream<List<Note>> watchNotes(String bookId) {
    return (_db.select(_db.notes)
          ..where((n) => n.bookId.equals(bookId))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .watch();
  }
}

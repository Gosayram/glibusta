import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../bookmarks/data/bookmark_repository.dart';
import '../../notes/data/note_repository.dart';
import '../../quotes/data/quote_repository.dart';

enum AnnotationType { bookmarks, notes, quotes }

class AnnotationData {
  final List<Bookmark> bookmarks;
  final List<Note> notes;
  final List<Quote> quotes;

  const AnnotationData({
    required this.bookmarks,
    required this.notes,
    required this.quotes,
  });
}

final bookmarkRepoProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.watch(databaseProvider));
});

final noteRepoProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(databaseProvider));
});

final quoteRepoProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(ref.watch(databaseProvider));
});

final allAnnotationsProvider = FutureProvider.family<AnnotationData, String?>((ref, bookId) async {
  final db = ref.watch(databaseProvider);
  final bookmarkRepo = ref.watch(bookmarkRepoProvider);
  final noteRepo = ref.watch(noteRepoProvider);
  final quoteRepo = ref.watch(quoteRepoProvider);

  final List<Bookmark> bookmarks;
  final List<Note> notes;
  final List<Quote> quotes;

  if (bookId != null) {
    bookmarks = await bookmarkRepo.getAllBookmarks(bookId);
    notes = await noteRepo.getAllNotes(bookId);
    quotes = await quoteRepo.getAllQuotes(bookId);
  } else {
    bookmarks = await db.select(db.bookmarks).get();
    notes = await db.select(db.notes).get();
    quotes = await db.select(db.quotes).get();
  }

  return AnnotationData(
    bookmarks: bookmarks,
    notes: notes,
    quotes: quotes,
  );
});

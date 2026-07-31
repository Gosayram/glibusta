import 'package:flutter/foundation.dart';
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

@immutable
class AnnotationPageParams {
  final String? bookId;
  final int limit;
  final int offset;

  const AnnotationPageParams({this.bookId, required this.limit, required this.offset});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationPageParams &&
          bookId == other.bookId &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(bookId, limit, offset);
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

final annotationPageProvider = FutureProvider.family<AnnotationData, AnnotationPageParams>((
  ref,
  params,
) async {
  final bookmarkRepo = ref.watch(bookmarkRepoProvider);
  final noteRepo = ref.watch(noteRepoProvider);
  final quoteRepo = ref.watch(quoteRepoProvider);

  final results = await Future.wait([
    bookmarkRepo.getBookmarksPage(
      bookId: params.bookId,
      limit: params.limit,
      offset: params.offset,
    ),
    noteRepo.getNotesPage(
      bookId: params.bookId,
      limit: params.limit,
      offset: params.offset,
    ),
    quoteRepo.getQuotesPage(
      bookId: params.bookId,
      limit: params.limit,
      offset: params.offset,
    ),
  ]);

  return AnnotationData(
    bookmarks: results[0] as List<Bookmark>,
    notes: results[1] as List<Note>,
    quotes: results[2] as List<Quote>,
  );
});

final annotationCountProvider = FutureProvider.family<int, String?>((ref, bookId) async {
  final bookmarkRepo = ref.watch(bookmarkRepoProvider);
  final noteRepo = ref.watch(noteRepoProvider);
  final quoteRepo = ref.watch(quoteRepoProvider);

  final counts = await Future.wait([
    bookmarkRepo.countBookmarks(bookId: bookId),
    noteRepo.countNotes(bookId: bookId),
    quoteRepo.countQuotes(bookId: bookId),
  ]);

  return counts[0] + counts[1] + counts[2];
});

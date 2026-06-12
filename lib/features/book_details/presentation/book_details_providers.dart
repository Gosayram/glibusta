import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../reader/data/book_open_service.dart';
import '../../reader/data/parsers/normalized_book.dart';
import '../data/book_comments_service.dart';

final seriesForBookProvider = FutureProvider.autoDispose.family<List<Sery>, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.getSeriesForBook(bookId);
});

final chaptersForBookProvider = FutureProvider.autoDispose.family<NormalizedBook?, String>((
  ref,
  bookId,
) async {
  final service = ref.watch(bookOpenServiceProvider);
  return service.getCachedBook(bookId);
});

final bookmarksForBookProvider = FutureProvider.autoDispose.family<List<Bookmark>, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.getBookmarksForBook(bookId);
});

final quotesForBookProvider = FutureProvider.autoDispose.family<List<Quote>, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.getQuotesForBook(bookId);
});

final commentsForBookProvider = FutureProvider.autoDispose.family<List<BookComment>, String>((
  ref,
  bookId,
) async {
  final service = ref.watch(bookCommentsServiceProvider);
  return service.getComments(bookId);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../shared/models/download_task.dart';
import '../../reader/data/book_open_service.dart';
import '../../reader/data/parsers/normalized_book.dart';
import '../data/book_comments_service.dart';
import '../data/book_details_repository_impl.dart';

final bookDetailsProvider = FutureProvider.family<BookDetails, String>((ref, bookId) async {
  final repository = ref.watch(bookDetailsRepositoryProvider);
  return repository.getBookDetails(bookId);
});

final bookReadingProgressProvider = FutureProvider.family<ReadingProgressData?, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.bookDao.getReadingProgress(bookId);
});

final seriesForBookProvider = FutureProvider.autoDispose.family<List<Sery>, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.seriesDao.getSeriesForBook(bookId);
});

final chaptersForBookProvider = FutureProvider.autoDispose.family<NormalizedBook?, String>((
  ref,
  bookId,
) async {
  final service = ref.watch(bookOpenServiceProvider);
  try {
    return await service.openBookWithCache(bookId);
  } on Object catch (_) {
    return null;
  }
});

final bookmarksForBookProvider = FutureProvider.autoDispose.family<List<Bookmark>, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.bookmarkDao.getBookmarksForBook(bookId);
});

final quotesForBookProvider = FutureProvider.autoDispose.family<List<Quote>, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  return db.bookmarkDao.getQuotesForBook(bookId);
});

final commentsForBookProvider = FutureProvider.autoDispose.family<List<BookComment>, String>((
  ref,
  bookId,
) async {
  final service = ref.watch(bookCommentsServiceProvider);
  return service.getComments(bookId);
});

final bookDownloadStateProvider = FutureProvider.autoDispose.family<BookDownloadState, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.downloads)..where((d) => d.bookId.equals(bookId))).get();
  for (final row in rows) {
    if (row.status == DownloadStatusDb.completed) {
      return BookDownloadState.downloaded;
    }
    if (row.status == DownloadStatusDb.queued || row.status == DownloadStatusDb.running) {
      return BookDownloadState.downloading;
    }
  }
  return BookDownloadState.notDownloaded;
});

enum BookDownloadState { notDownloaded, downloading, downloaded }

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../shared/models/download_task.dart';
import '../../reader/data/book_open_service.dart';
import '../../reader/data/parsers/normalized_book.dart';
import '../../search/data/composite_source.dart';
import '../data/book_comments_service.dart';

final bookDetailsProvider = FutureProvider.autoDispose.family<BookDetails, String>((
  ref,
  bookId,
) async {
  final source = ref.watch(bookSourceProvider);
  return source.getBookDetails(bookId);
});

final savedBookProvider = StreamProvider.autoDispose.family<SavedBook?, String>((ref, bookId) {
  final db = ref.watch(databaseProvider);
  return db.bookDao.watchBookById(bookId);
});

final bookReadingProgressProvider = FutureProvider.autoDispose.family<ReadingProgressData?, String>(
  (
    ref,
    bookId,
  ) async {
    final db = ref.watch(databaseProvider);
    return db.bookDao.getReadingProgress(bookId);
  },
);

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

final bookmarksForBookProvider = StreamProvider.autoDispose.family<List<Bookmark>, String>((
  ref,
  bookId,
) {
  final db = ref.watch(databaseProvider);
  return db.bookmarkDao.watchBookmarksForBook(bookId);
});

final quotesForBookProvider = StreamProvider.autoDispose.family<List<Quote>, String>((
  ref,
  bookId,
) {
  final db = ref.watch(databaseProvider);
  return db.bookmarkDao.watchQuotesForBook(bookId);
});

final commentsForBookProvider = FutureProvider.autoDispose.family<List<BookComment>, String>((
  ref,
  bookId,
) async {
  final service = ref.watch(bookCommentsServiceProvider);
  return service.getComments(bookId);
});

final bookDownloadStateProvider = StreamProvider.autoDispose.family<BookDownloadState, String>((
  ref,
  bookId,
) async* {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.downloads)..where((d) => d.bookId.equals(bookId));
  await for (final rows in query.watch()) {
    yield _mapDownloadRows(rows);
  }
});

BookDownloadState _mapDownloadRows(List<Download> rows) {
  for (final row in rows) {
    if (row.status == DownloadStatusDb.completed) {
      return BookDownloadState.downloaded;
    }
    if (row.status == DownloadStatusDb.queued || row.status == DownloadStatusDb.running) {
      return BookDownloadState.downloading;
    }
  }
  return BookDownloadState.notDownloaded;
}

enum BookDownloadState { notDownloaded, downloading, downloaded }

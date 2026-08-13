import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'series_dao.g.dart';

@DriftAccessor(tables: [Series, BookSeries])
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  SeriesDao(super.attachedDatabase);

  Future<List<Sery>> getAllSeries() async => select(series).get();

  Future<Sery?> getSeriesById(String id) async =>
      (select(series)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSeries(SeriesCompanion entry) => into(series).insertOnConflictUpdate(entry);

  Future<List<BookSery>> getBookSeriesForBook(String bookId) async =>
      (select(bookSeries)..where((t) => t.bookId.equals(bookId))).get();

  Future<List<Sery>> getSeriesForBook(String bookId) async {
    final bsRows = await getBookSeriesForBook(bookId);
    if (bsRows.isEmpty) return [];
    final seriesIds = bsRows.map((r) => r.seriesId).toList();
    return (select(series)..where((t) => t.id.isIn(seriesIds))).get();
  }

  Future<List<BookSery>> getBooksInSeries(String seriesId) async =>
      (select(bookSeries)..where((t) => t.seriesId.equals(seriesId))).get();

  Future<int> deleteSeries(String seriesId) {
    return attachedDatabase.transaction(() async {
      await (delete(bookSeries)..where((t) => t.seriesId.equals(seriesId))).go();
      return (delete(series)..where((t) => t.id.equals(seriesId))).go();
    });
  }

  Future<int> removeBookFromSeries(String bookId, String seriesId) => (delete(
    bookSeries,
  )..where((t) => t.bookId.equals(bookId) & t.seriesId.equals(seriesId))).go();
}

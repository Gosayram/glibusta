import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SeriesDao', () {
    test('insertSeries and getAllSeries', () async {
      await db.seriesDao.insertSeries(
        SeriesCompanion.insert(id: 's1', name: 'Series 1'),
      );
      await db.seriesDao.insertSeries(
        SeriesCompanion.insert(id: 's2', name: 'Series 2'),
      );
      final all = await db.seriesDao.getAllSeries();
      expect(all.length, 2);
    });

    test('getSeriesById returns correct series', () async {
      await db.seriesDao.insertSeries(
        SeriesCompanion.insert(id: 's1', name: 'Series 1'),
      );
      final s = await db.seriesDao.getSeriesById('s1');
      expect(s, isNotNull);
      expect(s!.name, 'Series 1');
    });

    test('getSeriesById returns null for missing', () async {
      final s = await db.seriesDao.getSeriesById('missing');
      expect(s, isNull);
    });

    test('getBooksInSeries and getSeriesForBook', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b2', title: 'Book 2'),
      );
      await db.seriesDao.insertSeries(
        SeriesCompanion.insert(id: 's1', name: 'Series 1'),
      );

      await db
          .into(db.bookSeries)
          .insert(
            BookSeriesCompanion.insert(bookId: 'b1', seriesId: 's1'),
          );
      await db
          .into(db.bookSeries)
          .insert(
            BookSeriesCompanion.insert(bookId: 'b2', seriesId: 's1'),
          );

      final booksInSeries = await db.seriesDao.getBooksInSeries('s1');
      expect(booksInSeries.length, 2);

      final seriesForBook = await db.seriesDao.getSeriesForBook('b1');
      expect(seriesForBook.length, 1);
      expect(seriesForBook.first.name, 'Series 1');
    });

    test('getBookSeriesForBook returns book-series rows', () async {
      await db.bookDao.insertBook(
        SavedBooksCompanion.insert(id: 'b1', title: 'Book 1'),
      );
      await db.seriesDao.insertSeries(
        SeriesCompanion.insert(id: 's1', name: 'Series 1'),
      );
      await db
          .into(db.bookSeries)
          .insert(
            BookSeriesCompanion.insert(bookId: 'b1', seriesId: 's1'),
          );

      final rows = await db.seriesDao.getBookSeriesForBook('b1');
      expect(rows.length, 1);
      expect(rows.first.seriesId, 's1');
    });
  });
}

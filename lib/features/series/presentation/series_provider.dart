import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../library/data/book_repository_impl.dart';

part 'series_provider.g.dart';

@riverpod
Future<List<SeriesInfo>> allSeries(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final seriesList = await db.seriesDao.getAllSeries();

  // Batch: load all bookSeries rows for all series
  final allBookSeriesRows = <String, List<BookSery>>{};
  for (final s in seriesList) {
    final rows = await db.seriesDao.getBooksInSeries(s.id);
    if (rows.isNotEmpty) {
      allBookSeriesRows[s.id] = rows;
    }
  }

  // Collect all unique book IDs across all series
  final allBookIds = <String>{};
  for (final rows in allBookSeriesRows.values) {
    for (final r in rows) {
      allBookIds.add(r.bookId);
    }
  }

  if (allBookIds.isEmpty) {
    final infos = seriesList
        .map(
          (s) => SeriesInfo(
            id: s.id,
            name: s.name,
            description: s.description,
            books: const [],
            bookSeriesRows: const [],
          ),
        )
        .toList();
    infos.sort((a, b) => a.name.compareTo(b.name));
    return infos;
  }

  // Batch: load all books in one query
  final allBooks = await db.bookDao.getBooksByIds(allBookIds.toList());

  // Batch: resolve all authors in one query
  final allAuthorIds = <String>{};
  for (final row in allBooks) {
    allAuthorIds.addAll(row.authorIds);
  }
  final nameMap = await db.authorDao.getAuthorNamesByIds(allAuthorIds.toList());

  // Build book lookup
  final bookMap = <String, SavedBook>{};
  for (final row in allBooks) {
    bookMap[row.id] = row;
  }

  // Assemble results
  final infos = <SeriesInfo>[];
  for (final s in seriesList) {
    final bookSeriesRows = allBookSeriesRows[s.id];
    if (bookSeriesRows == null || bookSeriesRows.isEmpty) {
      infos.add(
        SeriesInfo(
          id: s.id,
          name: s.name,
          description: s.description,
          books: const [],
          bookSeriesRows: const [],
        ),
      );
      continue;
    }
    final books = <Book>[];
    for (final bsRow in bookSeriesRows) {
      final row = bookMap[bsRow.bookId];
      if (row == null) continue;
      final authorIds = row.authorIds;
      books.add(
        Book(
          id: row.id,
          title: row.title,
          authorIds: authorIds,
          authorNames: authorIds.map((id) => nameMap[id]).whereType<String>().toList(),
          genreIds: row.genreIds,
          description: row.description,
          coverUrl: row.coverUrl,
          publishDate: row.publishDate,
          availableFormats: const [],
          source: BookSourceInfo(
            sourceId: row.sourceId ?? '',
            sourceUrl: row.sourceUrl ?? '',
          ),
        ),
      );
    }
    infos.add(
      SeriesInfo(
        id: s.id,
        name: s.name,
        description: s.description,
        books: books,
        bookSeriesRows: bookSeriesRows,
      ),
    );
  }

  infos.sort((a, b) => a.name.compareTo(b.name));
  return infos;
}

@riverpod
Future<SeriesDetail?> seriesDetail(Ref ref, String seriesId) async {
  final db = ref.watch(databaseProvider);
  final s = await db.seriesDao.getSeriesById(seriesId);
  if (s == null) return null;

  final bookSeriesRows = await db.seriesDao.getBooksInSeries(seriesId);
  if (bookSeriesRows.isEmpty) {
    return SeriesDetail(
      id: s.id,
      name: s.name,
      description: s.description,
      books: const [],
    );
  }

  final repository = ref.watch(bookRepositoryProvider);
  final bookIds = bookSeriesRows.map((r) => r.bookId).toList();
  final fetchedBooks = await repository.getBooksByIds(bookIds);
  final byId = {for (final b in fetchedBooks) b.id: b};
  final books = [
    for (final id in bookIds)
      if (byId[id] != null) byId[id]!,
  ];

  return SeriesDetail(
    id: s.id,
    name: s.name,
    description: s.description,
    books: books,
  );
}

class SeriesInfo {
  final String id;
  final String name;
  final String? description;
  final List<Book> books;
  final List<BookSery> bookSeriesRows;

  const SeriesInfo({
    required this.id,
    required this.name,
    this.description,
    required this.books,
    required this.bookSeriesRows,
  });

  int get bookCount => books.length;
}

class SeriesDetail {
  final String id;
  final String name;
  final String? description;
  final List<Book> books;

  const SeriesDetail({
    required this.id,
    required this.name,
    this.description,
    required this.books,
  });
}

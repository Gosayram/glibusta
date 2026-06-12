import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../library/data/book_repository_impl.dart';

part 'series_provider.g.dart';

@riverpod
Future<List<SeriesInfo>> allSeries(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final seriesList = await db.getAllSeries();
  final infos = <SeriesInfo>[];

  for (final s in seriesList) {
    final bookSeriesRows = await db.getBooksInSeries(s.id);
    if (bookSeriesRows.isEmpty) continue;
    final bookIds = bookSeriesRows.map((r) => r.bookId).toList();
    final books = <Book>[];
    for (final id in bookIds) {
      final row = await db.getBookById(id);
      if (row != null) {
        final authorIds = row.authorIds;
        final nameMap = await db.getAuthorNamesByIds(authorIds);
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
  final s = await db.getSeriesById(seriesId);
  if (s == null) return null;

  final bookSeriesRows = await db.getBooksInSeries(seriesId);
  if (bookSeriesRows.isEmpty) {
    return SeriesDetail(
      id: s.id,
      name: s.name,
      description: s.description,
      books: const [],
    );
  }

  final repository = ref.watch(bookRepositoryProvider);
  final books = <Book>[];
  for (final row in bookSeriesRows) {
    final book = await repository.getBookById(row.bookId);
    if (book != null) books.add(book);
  }

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

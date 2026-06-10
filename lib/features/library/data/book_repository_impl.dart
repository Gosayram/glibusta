import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../domain/book_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BookRepositoryImpl(db);
});

class BookRepositoryImpl implements BookRepository {
  final AppDatabase _db;

  BookRepositoryImpl(this._db);

  @override
  Future<List<Book>> getAllBooks() async {
    final rows = await _db.getAllBooks();
    return _resolveAuthors(rows);
  }

  @override
  Future<List<Book>> getBooksWithProgress() async {
    final rows = await _db.getBooksWithProgress();
    return _resolveAuthors(rows);
  }

  @override
  Future<Book?> getBookById(String id) async {
    final row = await _db.getBookById(id);
    if (row == null) return null;
    final books = await _resolveAuthors([row]);
    return books.first;
  }

  @override
  Future<void> saveBook(Book book) async {
    await _db.insertBook(
      SavedBooksCompanion(
        id: Value(book.id),
        title: Value(book.title),
        authorIds: Value(jsonEncode(book.authorIds)),
        genreIds: Value(jsonEncode(book.genreIds)),
        description: Value(book.description),
        coverUrl: Value(book.coverUrl),
        publishDate: Value(book.publishDate),
        sourceId: Value(book.source.sourceId),
        sourceUrl: Value(book.source.sourceUrl),
      ),
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    await _db.deleteBook(id);
  }

  @override
  Future<bool> isBookInLibrary(String id) async {
    final book = await _db.getBookById(id);
    return book != null;
  }

  Future<List<Book>> _resolveAuthors(List<SavedBook> rows) async {
    final allAuthorIds = <String>{};
    for (final row in rows) {
      if (row.authorIds.isNotEmpty) {
        final ids = List<String>.from(jsonDecode(row.authorIds) as List<dynamic>);
        allAuthorIds.addAll(ids);
      }
    }
    final nameMap = await _db.getAuthorNamesByIds(allAuthorIds.toList());
    return rows.map((row) => _rowToBook(row, nameMap)).toList();
  }

  Book _rowToBook(SavedBook row, [Map<String, String>? authorNames]) {
    final authorIds = row.authorIds.isNotEmpty
        ? List<String>.from(jsonDecode(row.authorIds) as List<dynamic>)
        : <String>[];
    final genreIds = row.genreIds.isNotEmpty
        ? List<String>.from(jsonDecode(row.genreIds) as List<dynamic>)
        : <String>[];
    final names = authorNames != null
        ? authorIds.map((id) => authorNames[id]).whereType<String>().toList()
        : <String>[];

    final statusStr = row.readingStatus;
    final readingStatus = ReadingStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ReadingStatus.none,
    );

    return Book(
      id: row.id,
      title: row.title,
      authorIds: authorIds,
      authorNames: names,
      genreIds: genreIds,
      description: row.description,
      coverUrl: row.coverUrl,
      publishDate: row.publishDate,
      availableFormats: const [],
      source: BookSourceInfo(
        sourceId: row.sourceId ?? '',
        sourceUrl: row.sourceUrl ?? '',
      ),
      readingStatus: readingStatus,
    );
  }
}

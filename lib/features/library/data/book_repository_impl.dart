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
    return rows.map(_rowToBook).toList();
  }

  @override
  Future<Book?> getBookById(String id) async {
    final row = await _db.getBookById(id);
    if (row == null) return null;
    return _rowToBook(row);
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

  Book _rowToBook(SavedBook row) {
    final authorIds = row.authorIds.isNotEmpty
        ? List<String>.from(jsonDecode(row.authorIds) as List<dynamic>)
        : <String>[];
    final genreIds = row.genreIds.isNotEmpty
        ? List<String>.from(jsonDecode(row.genreIds) as List<dynamic>)
        : <String>[];

    return Book(
      id: row.id,
      title: row.title,
      authorIds: authorIds,
      genreIds: genreIds,
      description: row.description,
      coverUrl: row.coverUrl,
      publishDate: row.publishDate,
      availableFormats: const [],
      source: BookSourceInfo(
        sourceId: row.sourceId ?? '',
        sourceUrl: row.sourceUrl ?? '',
      ),
    );
  }
}

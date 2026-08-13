import 'dart:io';

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
    final rows = await _db.bookDao.getAllBooks();
    return _resolveAuthors(rows);
  }

  @override
  Future<List<Book>> getPagedBooks({
    required int limit,
    int offset = 0,
    BookSortField sortField = BookSortField.addedAt,
    bool ascending = false,
    String? formatFilter,
    String? collectionId,
  }) async {
    List<String>? bookIds;
    if (collectionId != null) {
      final colBooks = await _db.collectionDao.getBooksInCollection(collectionId);
      bookIds = colBooks.map((b) => b.id).toList();
      if (bookIds.isEmpty) return [];
    }
    final List<SavedBook> rows;
    if (sortField == BookSortField.progress) {
      rows = await _db.bookDao.getPagedBooksWithProgress(
        limit: limit,
        offset: offset,
        ascending: ascending,
        formatFilter: formatFilter,
        bookIds: bookIds,
      );
    } else {
      rows = await _db.bookDao.getPagedBooks(
        limit: limit,
        offset: offset,
        orderBy: _buildOrderBy(sortField, ascending),
        formatFilter: formatFilter,
        bookIds: bookIds,
      );
    }
    return _resolveAuthors(rows);
  }

  @override
  Future<List<Book>> searchBooksPaged(
    String query, {
    required int limit,
    int offset = 0,
    String? formatFilter,
  }) async {
    final rows = await _db.bookDao.searchBooksPaged(
      query,
      limit: limit,
      offset: offset,
      formatFilter: formatFilter,
    );
    return _resolveAuthors(rows);
  }

  List<OrderingTerm Function($SavedBooksTable)> _buildOrderBy(
    BookSortField field,
    bool ascending,
  ) {
    final direction = ascending ? OrderingMode.asc : OrderingMode.desc;
    return switch (field) {
      BookSortField.addedAt => [
        (t) => OrderingTerm(expression: t.addedAt, mode: direction),
        (t) => OrderingTerm(expression: t.id),
      ],
      BookSortField.title => [
        (t) => OrderingTerm(expression: t.title, mode: direction),
        (t) => OrderingTerm(expression: t.id),
      ],
      BookSortField.progress => [
        (t) => OrderingTerm(expression: t.addedAt, mode: direction),
        (t) => OrderingTerm(expression: t.id),
      ],
    };
  }

  @override
  Future<List<Book>> getBooksByIds(List<String> ids) async {
    final rows = await _db.bookDao.getBooksByIds(ids);
    return _resolveAuthors(rows);
  }

  @override
  Future<List<Book>> searchBooks(String query) async {
    final rows = await _db.bookDao.searchBooks(query);
    return _resolveAuthors(rows);
  }

  @override
  Future<List<Book>> getBooksWithProgress() async {
    final rows = await _db.bookDao.getBooksWithProgress();
    return _resolveAuthors(rows);
  }

  @override
  Future<Book?> getBookById(String id) async {
    final row = await _db.bookDao.getBookById(id);
    if (row == null) return null;
    final books = await _resolveAuthors([row]);
    return books.first;
  }

  @override
  Future<void> saveBook(Book book) async {
    await _db.bookDao.insertBook(
      SavedBooksCompanion(
        id: Value(book.id),
        title: Value(book.title),
        authorIds: Value(book.authorIds),
        genreIds: Value(book.genreIds),
        description: Value(book.description),
        coverUrl: Value(book.coverUrl),
        publishDate: Value(book.publishDate),
        sourceId: Value(book.source.sourceId),
        sourceUrl: Value(book.source.sourceUrl),
      ),
    );
  }

  @override
  Future<void> updateBook(Book book) async {
    await _db.bookDao.updateBook(
      bookId: book.id,
      title: book.title,
      authorIds: book.authorIds,
      description: book.description,
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    final book = await _db.bookDao.getBookById(id);
    await _db.bookDao.deleteBook(id);
    if (book?.coverPath != null) {
      try {
        final file = File(book!.coverPath!);
        if (await file.exists()) await file.delete();
      } on Object catch (_) {}
    }
  }

  @override
  Future<bool> isBookInLibrary(String id) async {
    final book = await _db.bookDao.getBookById(id);
    return book != null;
  }

  Future<List<Book>> _resolveAuthors(List<SavedBook> rows) async {
    final allAuthorIds = <String>{};
    for (final row in rows) {
      if (row.authorIds.isNotEmpty) {
        allAuthorIds.addAll(row.authorIds);
      }
    }
    final nameMap = await _db.authorDao.getAuthorNamesByIds(allAuthorIds.toList());
    return rows.map((row) => _rowToBook(row, nameMap)).toList();
  }

  Book _rowToBook(SavedBook row, [Map<String, String>? authorNames]) {
    final authorIds = row.authorIds;
    final genreIds = row.genreIds;
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
      coverPath: row.coverPath,
      publishDate: row.publishDate,
      dateAdded: row.addedAt,
      availableFormats: const [],
      source: BookSourceInfo(
        sourceId: row.sourceId ?? '',
        sourceUrl: row.sourceUrl ?? '',
      ),
      readingStatus: readingStatus,
    );
  }
}

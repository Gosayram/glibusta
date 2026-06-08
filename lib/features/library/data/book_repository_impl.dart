import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/book.dart';

final bookRepositoryProvider = Provider<BookRepositoryImpl>((ref) {
  return BookRepositoryImpl();
});

class BookRepositoryImpl {
  final List<Book> _books = [];

  Future<List<Book>> getLocalLibrary() async {
    return _books;
  }

  Future<void> saveBook(Book book) async {
    _books.add(book);
  }

  Future<void> deleteBook(String bookId) async {
    _books.removeWhere((b) => b.id == bookId);
  }
}
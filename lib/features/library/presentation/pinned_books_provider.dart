import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/book.dart';
import '../data/book_repository_impl.dart';

part 'pinned_books_provider.g.dart';

const _maxPinnedBooks = 5;
const _pinnedKey = 'pinned_book_ids';

@riverpod
class PinnedBooks extends _$PinnedBooks {
  @override
  List<String> build() {
    unawaited(_loadFromPrefs());
    return [];
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_pinnedKey) ?? [];
  }

  Future<void> toggle(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    if (state.contains(bookId)) {
      state = List.from(state)..remove(bookId);
    } else {
      if (state.length >= _maxPinnedBooks) {
        state = List.from(state)..removeLast();
      }
      state = List.from(state)..add(bookId);
    }
    await prefs.setStringList(_pinnedKey, state);
  }

  bool isPinned(String bookId) => state.contains(bookId);

  int get count => state.length;
  bool get isFull => state.length >= _maxPinnedBooks;
}

@riverpod
Future<List<Book>> pinnedBooksList(Ref ref) async {
  final pinnedIds = ref.watch(pinnedBooksProvider);
  if (pinnedIds.isEmpty) return [];

  final repository = ref.watch(bookRepositoryProvider);
  final allBooks = await repository.getAllBooks();

  final pinnedBooksList = <Book>[];
  for (final id in pinnedIds) {
    final book = allBooks.firstWhere(
      (b) => b.id == id,
      orElse: () => allBooks.first,
    );
    if (book.id == id) {
      pinnedBooksList.add(book);
    }
  }
  return pinnedBooksList;
}

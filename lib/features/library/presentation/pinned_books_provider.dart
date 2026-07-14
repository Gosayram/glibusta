import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/book.dart';
import '../data/book_repository_impl.dart';

part 'pinned_books_provider.g.dart';

const _maxPinnedBooks = 5;
const _pinnedKey = 'pinned_book_ids';

@riverpod
class PinnedBooks extends _$PinnedBooks {
  Future<void> _toggleQueue = Future.value();

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pinnedKey) ?? [];
  }

  Future<void> toggle(String bookId) {
    final next = _toggleQueue.then<void>(
      (_) => _toggle(bookId),
      onError: (Object _, StackTrace _) => _toggle(bookId),
    );
    _toggleQueue = next;
    return next;
  }

  Future<void> _toggle(String bookId) async {
    final current = await future;
    final prefs = await SharedPreferences.getInstance();
    List<String> updated;
    if (current.contains(bookId)) {
      updated = List.from(current)..remove(bookId);
    } else {
      updated = List.from(current);
      if (updated.length >= _maxPinnedBooks) {
        updated.removeLast();
      }
      updated.add(bookId);
    }
    await prefs.setStringList(_pinnedKey, updated);
    state = AsyncData(updated);
  }

  bool isPinned(String bookId) {
    final value = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    return value?.contains(bookId) ?? false;
  }

  int get count => switch (state) {
    AsyncData(:final value) => value.length,
    _ => 0,
  };
  bool get isFull => count >= _maxPinnedBooks;
}

@riverpod
Future<List<Book>> pinnedBooksList(Ref ref) async {
  final pinnedIds = await ref.watch(pinnedBooksProvider.future);
  if (pinnedIds.isEmpty) return [];

  final repository = ref.watch(bookRepositoryProvider);
  final allBooks = await repository.getAllBooks();
  if (allBooks.isEmpty) return [];

  final bookMap = {for (final b in allBooks) b.id: b};
  final pinnedBooksList = <Book>[];
  for (final id in pinnedIds) {
    final book = bookMap[id];
    if (book != null) pinnedBooksList.add(book);
  }
  return pinnedBooksList;
}

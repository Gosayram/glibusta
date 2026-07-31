import '../../../shared/models/book.dart';
import '../../../shared/utils/author_utils.dart';

/// Sort options that apply only to the current local library view.
enum LibrarySort {
  recentlyAdded,
  title,
  author;

  String get label => switch (this) {
    LibrarySort.recentlyAdded => 'Недавно добавленные',
    LibrarySort.title => 'По названию',
    LibrarySort.author => 'По автору',
  };
}

/// Returns a new, deterministically ordered list without mutating [books].
List<Book> sortLibraryBooks(Iterable<Book> books, LibrarySort sort) {
  final sorted = books.toList();
  sorted.sort((left, right) {
    final primary = switch (sort) {
      LibrarySort.recentlyAdded => _addedAt(right).compareTo(_addedAt(left)),
      LibrarySort.title => _compareText(left.title, right.title),
      LibrarySort.author => _compareAuthor(left.displayAuthor, right.displayAuthor),
    };
    return primary != 0 ? primary : _compareText(left.id, right.id);
  });
  return sorted;
}

DateTime _addedAt(Book book) => book.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);

int _compareText(String left, String right) => left.toLowerCase().compareTo(right.toLowerCase());

int _compareAuthor(String left, String right) =>
    normalizeAuthorForSort(left).compareTo(normalizeAuthorForSort(right));

import '../../../shared/models/book.dart';

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

/// Normalizes an author name for deterministic sorting.
///
/// Handles "Lastname, Firstname" vs "Firstname Lastname" by detecting the
/// comma pattern and swapping to "Lastname Firstname". Strips leading
/// articles and normalizes ё→е for Russian locale collation.
int _compareAuthor(String left, String right) =>
    _normalizeAuthor(left).compareTo(_normalizeAuthor(right));

String _normalizeAuthor(String author) {
  var name = author.trim().toLowerCase();

  // "Lastname, Firstname" → "lastname firstname" (remove comma, keep order)
  name = name.replaceAll(RegExp(r',\s*'), ' ');

  // ё → е for stable Russian collation
  name = name.replaceAll('ё', 'е');

  // Strip leading articles
  for (final article in const ['the ', 'a ', 'an ', 'der ', 'die ', 'das ', 'le ', 'la ', 'el ']) {
    if (name.startsWith(article)) {
      name = name.substring(article.length);
      break;
    }
  }

  return name;
}

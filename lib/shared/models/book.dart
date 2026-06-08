enum BookFormat { fb2, epub, mobi, pdf, txt, djvu }

class Book {
  final String id;
  final String title;
  final List<String> authorIds;
  final List<String> genreIds;
  final String? description;
  final String? coverUrl;
  final DateTime? publishDate;
  final List<BookFormat> availableFormats;
  final BookSourceInfo source;

  const Book({
    required this.id,
    required this.title,
    required this.authorIds,
    required this.genreIds,
    required this.description,
    required this.coverUrl,
    required this.publishDate,
    required this.availableFormats,
    required this.source,
  });
}

class BookSourceInfo {
  final String sourceId;
  final String sourceUrl;

  const BookSourceInfo({
    required this.sourceId,
    required this.sourceUrl,
  });
}

class Author {
  final String id;
  final String name;
  final List<String> bookIds;

  const Author({
    required this.id,
    required this.name,
    required this.bookIds,
  });
}

class Genre {
  final String id;
  final String name;
  final String? parentId;

  const Genre({
    required this.id,
    required this.name,
    required this.parentId,
  });
}

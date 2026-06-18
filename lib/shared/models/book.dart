enum BookFormat {
  fb2,
  epub,
  pdf,
  txt,
  mobi,
  azw3,
  prc,
  rtf,
  djvu,
  docx,
  cbz,
  cbr,
  unknown,
}

enum ReadingStatus {
  none,
  wantToRead,
  reading,
  finished,
  dropped,
}

class Book {
  final String id;
  final String title;
  final List<String> authorIds;
  final List<String> authorNames;
  final List<String> genreIds;
  final String? description;
  final String? coverUrl;
  final String? coverPath;
  final DateTime? publishDate;
  final DateTime? dateAdded;
  final List<BookFormat> availableFormats;
  final BookSourceInfo source;
  final ReadingStatus readingStatus;

  const Book({
    required this.id,
    required this.title,
    required this.authorIds,
    this.authorNames = const [],
    required this.genreIds,
    required this.description,
    required this.coverUrl,
    this.coverPath,
    required this.publishDate,
    this.dateAdded,
    required this.availableFormats,
    required this.source,
    this.readingStatus = ReadingStatus.none,
  });

  String get displayAuthor => authorNames.isNotEmpty
      ? authorNames.join(', ')
      : authorIds.isNotEmpty
      ? authorIds.first
      : '';

  String get readingStatusLabel => readingStatus.readingStatusLabel;
}

extension ReadingStatusExtension on ReadingStatus {
  String get label {
    switch (this) {
      case ReadingStatus.none:
        return 'Без статуса';
      case ReadingStatus.wantToRead:
        return 'Хочу прочитать';
      case ReadingStatus.reading:
        return 'Читаю';
      case ReadingStatus.finished:
        return 'Прочитано';
      case ReadingStatus.dropped:
        return 'Брошено';
    }
  }

  String get readingStatusLabel => this == ReadingStatus.none ? '' : label;
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

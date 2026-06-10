import 'book.dart';

class SearchQuery {
  final String query;
  final String? author;
  final String? title;
  final String? series;
  final String? genre;
  final SearchFilters filters;
  final int page;

  const SearchQuery({
    required this.query,
    this.author,
    this.title,
    this.series,
    this.genre,
    this.filters = const SearchFilters(),
    this.page = 0,
  });

  bool get hasFilters =>
      filters.hasFilters || genre != null || author != null || title != null || series != null;
}

class SearchFilters {
  final BookFormat? format;
  final String? language;
  final String? genre;

  const SearchFilters({
    this.format,
    this.language,
    this.genre,
  });

  bool get hasFilters => format != null || _hasText(language) || _hasText(genre);

  SearchFilters copyWith({
    BookFormat? format,
    String? language,
    String? genre,
    bool clearFormat = false,
    bool clearLanguage = false,
    bool clearGenre = false,
  }) {
    return SearchFilters(
      format: clearFormat ? null : (format ?? this.format),
      language: clearLanguage ? null : (language ?? this.language),
      genre: clearGenre ? null : (genre ?? this.genre),
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

class SearchResultPage {
  final List<Book> books;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;

  const SearchResultPage({
    required this.books,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
  });
}

// ── Response models ───────────────────────────────────────────────────────────

class SearchByNameResponse {
  final List<SearchBookItem> books;

  const SearchByNameResponse({required this.books});
}

class SearchBookItem {
  final String id;
  final String name;
  final List<SearchAuthorItem> authors;

  const SearchBookItem({required this.id, required this.name, this.authors = const []});
}

class SearchAuthorsResponse {
  final List<SearchAuthorItem> authors;

  const SearchAuthorsResponse({required this.authors});
}

class SearchAuthorItem {
  final String id;
  final String name;

  const SearchAuthorItem({required this.id, required this.name});
}

class SearchSeriesResponse {
  final List<SearchSeriesItem> series;

  const SearchSeriesResponse({required this.series});
}

class SearchSeriesItem {
  final String id;
  final String name;

  const SearchSeriesItem({required this.id, required this.name});
}

class SearchGenresResponse {
  final List<SearchGenreItem> genres;

  const SearchGenresResponse({required this.genres});
}

class SearchGenreItem {
  final String id;
  final String name;

  const SearchGenreItem({required this.id, required this.name});
}

class BookDetailsResponse {
  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final List<String> authors;
  final List<String> authorIds;
  final List<String> formats;
  final List<String> genres;
  final List<SeriesInfoItem> series;

  const BookDetailsResponse({
    required this.id,
    required this.title,
    required this.description,
    this.coverUrl,
    required this.authors,
    this.authorIds = const [],
    required this.formats,
    this.genres = const [],
    this.series = const [],
  });
}

class SeriesInfoItem {
  final String id;
  final String name;

  const SeriesInfoItem({required this.id, required this.name});
}

class RecentBooksResponse {
  final List<SearchBookItem> books;

  const RecentBooksResponse({required this.books});
}

class AuthorDetailResponse {
  final String id;
  final String name;
  final String? avatarUrl;
  final String biography;
  final List<AuthorSeriesGroup> seriesGroups;
  final List<SearchBookItem> books;

  const AuthorDetailResponse({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.biography = '',
    this.seriesGroups = const [],
    required this.books,
  });
}

class AuthorSeriesGroup {
  final String id;
  final String name;
  final List<AuthorGenreItem> genres;
  final List<AuthorBookItem> books;

  AuthorSeriesGroup({
    required this.id,
    required this.name,
    List<AuthorGenreItem>? genres,
    List<AuthorBookItem>? books,
  }) : genres = genres ?? [],
       books = books ?? [];
}

class AuthorGenreItem {
  final String id;
  final String name;

  const AuthorGenreItem({required this.id, required this.name});
}

class AuthorBookItem {
  final String id;
  final String name;
  final int? index;
  final String? size;
  final int? pages;
  final double? rating;
  final List<String> formats;

  const AuthorBookItem({
    required this.id,
    required this.name,
    this.index,
    this.size,
    this.pages,
    this.rating,
    this.formats = const [],
  });
}

class GenreBooksResponse {
  final String id;
  final String name;
  final List<SearchBookItem> books;

  const GenreBooksResponse({
    required this.id,
    required this.name,
    required this.books,
  });
}

class GenreListResponse {
  final List<SearchGenreItem> genres;

  const GenreListResponse({required this.genres});
}

class SeriesDetailResponse {
  final String id;
  final String name;
  final List<SearchBookItem> books;

  const SeriesDetailResponse({
    required this.id,
    required this.name,
    required this.books,
  });
}

class OpdsBooksResponse {
  final List<SearchBookItem> books;

  const OpdsBooksResponse({required this.books});
}

class OpdsGenresResponse {
  final List<SearchGenreItem> genres;

  const OpdsGenresResponse({required this.genres});
}

class MessagesResponse {
  final List<MessageItem> messages;

  const MessagesResponse({required this.messages});
}

class MessageItem {
  final String sender;
  final String subject;
  final String date;

  const MessageItem({
    required this.sender,
    required this.subject,
    required this.date,
  });
}

class UserProfileResponse {
  final String userId;
  final String username;

  const UserProfileResponse({required this.userId, required this.username});
}

class RecommendationsResponse {
  final List<SearchBookItem> books;

  const RecommendationsResponse({required this.books});
}

class BwListResponse {
  final String userId;
  final List<SearchBookItem> books;

  const BwListResponse({required this.userId, required this.books});
}

class TrackerResponse {
  final List<SearchBookItem> books;

  const TrackerResponse({required this.books});
}

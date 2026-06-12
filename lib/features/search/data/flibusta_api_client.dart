import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/http/dio_provider.dart';
import '../../../core/http/http_client.dart';

part 'flibusta_api_client.g.dart';

@riverpod
FlibustaApiClient flibustaApiClient(Ref ref) {
  final httpClient = ref.watch(httpClientProvider);
  final dio = ref.watch(dioProvider);
  return FlibustaApiClient(httpClient, dio);
}

class FlibustaApiClient {
  final HttpClient _httpClient;
  final Dio _dio;

  FlibustaApiClient(this._httpClient, this._dio);

  Dio get dio => _dio;

  Future<String> _getText(String relativePath, {CancelToken? cancelToken}) async {
    final base = _dio.options.baseUrl;
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return _httpClient.get('$normalizedBase/$relativePath', cancelToken: cancelToken);
  }

  Future<SearchByNameResponse> searchBooksByName(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chb=on';
    final response = await _getText(url);
    return _parseSearchByNameResponse(response);
  }

  Future<SearchByNameResponse> searchBooksByNameOpds(
    String name, {
    int page = 0,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final url =
        'opds/opensearch?searchTerm=${Uri.encodeComponent(name)}&searchType=books&pageNumber=$page';
    final response = await _getText(url, cancelToken: cancelToken);
    return _parseOpdsSearchResponse(response);
  }

  Future<SearchAuthorsResponse> searchAuthors(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&cha=on';
    final response = await _getText(url);
    return _parseSearchAuthorsResponse(response);
  }

  Future<SearchSeriesResponse> searchBooksBySeries(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chs=on';
    final response = await _getText(url);
    return _parseSearchSeriesResponse(response);
  }

  Future<SearchGenresResponse> searchGenres(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chg=on';
    final response = await _getText(url);
    return _parseSearchGenresResponse(response);
  }

  Future<BookDetailsResponse> getBookDetails(String bookId) async {
    final url = 'b/$bookId';
    final response = await _getText(url);
    return _parseBookDetailsResponse(response, bookId);
  }

  Future<String> getDownloadUrl(String bookId, String format) async {
    final base = _dio.options.baseUrl;
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$normalizedBase/b/$bookId/download/$format';
  }

  SearchByNameResponse _parseSearchByNameResponse(String html) {
    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<li>.*?<a href="/b/(\d+)">(.*?)</a>.*?</li>', dotAll: true);
    final matches = bookRegex.allMatches(html);

    for (final match in matches) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return SearchByNameResponse(books: books);
  }

  SearchByNameResponse _parseOpdsSearchResponse(String xml) {
    final books = <SearchBookItem>[];
    final entryRegex = RegExp(r'<entry>.*?</entry>', dotAll: true);
    final entries = entryRegex.allMatches(xml);

    for (final entry in entries) {
      final entryXml = entry.group(0) ?? '';
      final idMatch = RegExp(r'<id>.*?/b/(\d+)</id>').firstMatch(entryXml);
      final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(entryXml);

      if (idMatch != null && titleMatch != null) {
        final id = idMatch.group(1) ?? '';
        final name = titleMatch.group(1) ?? '';
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return SearchByNameResponse(books: books);
  }

  SearchAuthorsResponse _parseSearchAuthorsResponse(String html) {
    final authors = <SearchAuthorItem>[];
    final authorRegex = RegExp(r'<li>.*?<a href="/a/(\d+)">(.*?)</a>.*?</li>', dotAll: true);
    final matches = authorRegex.allMatches(html);

    for (final match in matches) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        authors.add(SearchAuthorItem(id: id, name: name));
      }
    }

    return SearchAuthorsResponse(authors: authors);
  }

  SearchSeriesResponse _parseSearchSeriesResponse(String html) {
    final series = <SearchSeriesItem>[];
    final seriesRegex = RegExp(r'<li>.*?<a href="/sequence/(\d+)">(.*?)</a>.*?</li>', dotAll: true);
    final matches = seriesRegex.allMatches(html);

    for (final match in matches) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        series.add(SearchSeriesItem(id: id, name: name));
      }
    }

    return SearchSeriesResponse(series: series);
  }

  SearchGenresResponse _parseSearchGenresResponse(String html) {
    final genres = <SearchGenreItem>[];
    final genreRegex = RegExp(r'<li>.*?<a href="/g/([^"]+)">(.*?)</a>.*?</li>', dotAll: true);
    final matches = genreRegex.allMatches(html);

    for (final match in matches) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        genres.add(SearchGenreItem(id: id, name: name));
      }
    }

    return SearchGenresResponse(genres: genres);
  }

  Future<RecentBooksResponse> getRecentBooks({
    String? lang,
    String? type,
  }) async {
    final params = <String>[];
    if (lang != null) params.add('lang=$lang');
    if (type != null) params.add('type=$type');
    final url = 'new${params.isNotEmpty ? '?${params.join('&')}' : ''}';
    final response = await _getText(url);
    return _parseRecentBooksResponse(response);
  }

  Future<AuthorDetailResponse> getAuthorDetail(String authorId) async {
    final response = await _getText('a/$authorId');
    return _parseAuthorDetailResponse(response, authorId);
  }

  Future<GenreBooksResponse> getGenreBooks(
    String genreId, {
    String order = 'a',
  }) async {
    final response = await _getText('g/$genreId?order=$order');
    return _parseGenreBooksResponse(response, genreId);
  }

  Future<GenreListResponse> getGenreList() async {
    final response = await _getText('genres');
    return _parseGenreListResponse(response);
  }

  Future<SeriesDetailResponse> getSeriesDetail(String seriesId) async {
    final response = await _getText('sequence/$seriesId');
    return _parseSeriesDetailResponse(response, seriesId);
  }

  Future<OpdsBooksResponse> getPopularBooksOpds({int page = 0}) async {
    final response = await _getText('opds/popular?pageNumber=$page');
    return _parseOpdsBooksResponse(response);
  }

  Future<OpdsBooksResponse> getRecentBooksOpds({int page = 0}) async {
    final response = await _getText('opds/recent?pageNumber=$page');
    return _parseOpdsBooksResponse(response);
  }

  Future<OpdsGenresResponse> getGenresOpds() async {
    final response = await _getText('opds/genres');
    return _parseOpdsGenresResponse(response);
  }

  Future<bool> addToBookshelf(
    String bookId, {
    String? review,
    int? score,
  }) async {
    final data = <String, String>{
      'flag': 'on',
      'op': 'Сохранить',
    };
    if (review != null) data['body'] = review;
    if (score != null) data['score'] = score.toString();
    final response = await _dio.post<String>(
      'polka/add/$bookId',
      data: data,
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    return response.statusCode == 200;
  }

  Future<bool> watchBook(String bookId) async {
    final response = await _getText('polka/watch/add/$bookId');
    return response.isNotEmpty;
  }

  Future<MessagesResponse> getMessages() async {
    final response = await _getText('messages');
    return _parseMessagesResponse(response);
  }

  Future<bool> sendMessage(
    String recipient,
    String subject,
    String body,
  ) async {
    final response = await _dio.post<String>(
      'messages/new',
      data: <String, String>{
        'recipient': recipient,
        'subject': subject,
        'body': body,
        'op': 'Отправить сообщение',
      },
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    return response.statusCode == 200 || response.statusCode == 302;
  }

  Future<UserProfileResponse> getUserProfile(String userId) async {
    final response = await _getText('user/$userId');
    return _parseUserProfileResponse(response, userId);
  }

  Future<RecommendationsResponse> getRecommendations({String? userId}) async {
    final url = userId != null ? 'rec?view=recs&user=$userId' : 'rec';
    final response = await _getText(url);
    return _parseRecommendationsResponse(response);
  }

  Future<BwListResponse> getBwList(String userId) async {
    final response = await _getText('bwlist/show/$userId');
    return _parseBwListResponse(response, userId);
  }

  Future<TrackerResponse> getTracker() async {
    final response = await _getText('tracker');
    return _parseTrackerResponse(response);
  }

  BookDetailsResponse _parseBookDetailsResponse(String html, String bookId) {
    final titleMatch = RegExp(r'<h1>(.*?)</h1>').firstMatch(html);
    final title = titleMatch?.group(1) ?? '';

    final descriptionMatch = RegExp(
      r'<div class="book_description">(.*?)</div>',
      dotAll: true,
    ).firstMatch(html);
    final description = descriptionMatch?.group(1) ?? '';

    final coverMatch = RegExp(r'<img src="(/i/[^"]+)"').firstMatch(html);
    final coverUrl = coverMatch?.group(1);

    final authorMatches = RegExp(r'<a href="/a/\d+">(.*?)</a>').allMatches(html);
    final authors = authorMatches.map((m) => m.group(1) ?? '').where((a) => a.isNotEmpty).toList();

    final formatMatches = RegExp(r'<a href="/b/\d+/(\w+)">').allMatches(html);
    final formats = formatMatches.map((m) => m.group(1) ?? '').where((f) => f.isNotEmpty).toList();

    return BookDetailsResponse(
      id: bookId,
      title: title,
      description: description,
      coverUrl: coverUrl,
      authors: authors,
      formats: formats,
    );
  }

  RecentBooksResponse _parseRecentBooksResponse(String html) {
    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>', dotAll: true);
    final matches = bookRegex.allMatches(html);
    final seen = <String>{};

    for (final match in matches) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return RecentBooksResponse(books: books);
  }

  AuthorDetailResponse _parseAuthorDetailResponse(
    String html,
    String authorId,
  ) {
    final titleMatch = RegExp(r'<h1>(.*?)</h1>').firstMatch(html);
    final name = titleMatch?.group(1)?.trim() ?? '';

    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>');
    final seen = <String>{};

    for (final match in bookRegex.allMatches(html)) {
      final id = match.group(1) ?? '';
      final bookName = match.group(2) ?? '';
      if (id.isNotEmpty && bookName.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: bookName));
      }
    }

    return AuthorDetailResponse(
      id: authorId,
      name: name,
      books: books,
    );
  }

  GenreBooksResponse _parseGenreBooksResponse(
    String html,
    String genreId,
  ) {
    final titleMatch = RegExp(r'<h1>(.*?)</h1>').firstMatch(html);
    final name = titleMatch?.group(1)?.trim() ?? '';

    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>');
    final seen = <String>{};

    for (final match in bookRegex.allMatches(html)) {
      final id = match.group(1) ?? '';
      final bookName = match.group(2) ?? '';
      if (id.isNotEmpty && bookName.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: bookName));
      }
    }

    return GenreBooksResponse(
      id: genreId,
      name: name,
      books: books,
    );
  }

  GenreListResponse _parseGenreListResponse(String html) {
    final genres = <SearchGenreItem>[];
    final genreRegex = RegExp(r'<a href="/g/([^"]+)">(.*?)</a>');
    final matches = genreRegex.allMatches(html);
    final seen = <String>{};

    for (final match in matches) {
      final slug = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (slug.isNotEmpty && name.isNotEmpty && seen.add(slug)) {
        genres.add(SearchGenreItem(id: slug, name: name));
      }
    }

    return GenreListResponse(genres: genres);
  }

  SeriesDetailResponse _parseSeriesDetailResponse(
    String html,
    String seriesId,
  ) {
    final titleMatch = RegExp(r'<h1>(.*?)</h1>').firstMatch(html);
    final name = titleMatch?.group(1)?.trim() ?? '';

    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>');
    final seen = <String>{};

    for (final match in bookRegex.allMatches(html)) {
      final id = match.group(1) ?? '';
      final bookName = match.group(2) ?? '';
      if (id.isNotEmpty && bookName.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: bookName));
      }
    }

    return SeriesDetailResponse(
      id: seriesId,
      name: name,
      books: books,
    );
  }

  OpdsBooksResponse _parseOpdsBooksResponse(String xml) {
    final books = <SearchBookItem>[];
    final entryRegex = RegExp(r'<entry>.*?</entry>', dotAll: true);
    final entries = entryRegex.allMatches(xml);

    for (final entry in entries) {
      final entryXml = entry.group(0) ?? '';
      final idMatch = RegExp(r'<id>.*?/b/(\d+)</id>').firstMatch(entryXml);
      final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(entryXml);

      if (idMatch != null && titleMatch != null) {
        final id = idMatch.group(1) ?? '';
        final name = titleMatch.group(1) ?? '';
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return OpdsBooksResponse(books: books);
  }

  OpdsGenresResponse _parseOpdsGenresResponse(String xml) {
    final genres = <SearchGenreItem>[];
    final entryRegex = RegExp(r'<entry>.*?</entry>', dotAll: true);
    final entries = entryRegex.allMatches(xml);

    for (final entry in entries) {
      final entryXml = entry.group(0) ?? '';
      final idMatch = RegExp(r'<id>.*?/g/([^<]+)</id>').firstMatch(entryXml);
      final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(entryXml);

      if (idMatch != null && titleMatch != null) {
        final slug = idMatch.group(1) ?? '';
        final name = titleMatch.group(1) ?? '';
        if (slug.isNotEmpty && name.isNotEmpty) {
          genres.add(SearchGenreItem(id: slug, name: name));
        }
      }
    }

    return OpdsGenresResponse(genres: genres);
  }

  MessagesResponse _parseMessagesResponse(String html) {
    final messages = <MessageItem>[];
    final rowRegex = RegExp(
      r'<tr[^>]*>.*?</tr>',
      dotAll: true,
    );
    final rows = rowRegex.allMatches(html);

    for (final row in rows) {
      final rowHtml = row.group(0) ?? '';
      final senderMatch = RegExp(
        r'<td[^>]*>.*?<a[^>]*>(.*?)</a>.*?</td>',
        dotAll: true,
      ).firstMatch(rowHtml);
      final subjectMatch = RegExp(
        r'<td[^>]*>.*?<a[^>]*>(.*?)</a>.*?</td>',
        dotAll: true,
      ).allMatches(rowHtml);

      if (senderMatch != null && subjectMatch.length >= 2) {
        final sender = _cleanHtml(senderMatch.group(1) ?? '');
        final subject = _cleanHtml(subjectMatch.last.group(1) ?? '');
        final date = '';
        if (sender.isNotEmpty || subject.isNotEmpty) {
          messages.add(
            MessageItem(sender: sender, subject: subject, date: date),
          );
        }
      }
    }

    return MessagesResponse(messages: messages);
  }

  UserProfileResponse _parseUserProfileResponse(
    String html,
    String userId,
  ) {
    final usernameMatch = RegExp(
      r'<div[^>]*class="[^"]*username[^"]*"[^>]*>(.*?)</div>',
      dotAll: true,
    ).firstMatch(html);
    final username = _cleanHtml(usernameMatch?.group(1) ?? '');

    return UserProfileResponse(
      userId: userId,
      username: username.isNotEmpty ? username : 'User #$userId',
    );
  }

  RecommendationsResponse _parseRecommendationsResponse(String html) {
    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>');
    final seen = <String>{};

    for (final match in bookRegex.allMatches(html)) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return RecommendationsResponse(books: books);
  }

  BwListResponse _parseBwListResponse(String html, String userId) {
    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>');
    final seen = <String>{};

    for (final match in bookRegex.allMatches(html)) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return BwListResponse(userId: userId, books: books);
  }

  TrackerResponse _parseTrackerResponse(String html) {
    final books = <SearchBookItem>[];
    final bookRegex = RegExp(r'<a href="/b/(\d+)">(.*?)</a>');
    final seen = <String>{};

    for (final match in bookRegex.allMatches(html)) {
      final id = match.group(1) ?? '';
      final name = match.group(2) ?? '';
      if (id.isNotEmpty && name.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return TrackerResponse(books: books);
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

class SearchByNameResponse {
  final List<SearchBookItem> books;

  const SearchByNameResponse({required this.books});
}

class SearchBookItem {
  final String id;
  final String name;

  const SearchBookItem({required this.id, required this.name});
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
  final List<String> formats;

  const BookDetailsResponse({
    required this.id,
    required this.title,
    required this.description,
    this.coverUrl,
    required this.authors,
    required this.formats,
  });
}

class RecentBooksResponse {
  final List<SearchBookItem> books;

  const RecentBooksResponse({required this.books});
}

class AuthorDetailResponse {
  final String id;
  final String name;
  final List<SearchBookItem> books;

  const AuthorDetailResponse({
    required this.id,
    required this.name,
    required this.books,
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

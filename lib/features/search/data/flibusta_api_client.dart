import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;
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

  // ── Search: Books (HTML) ────────────────────────────────────────────────────

  Future<SearchByNameResponse> searchBooksByName(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chb=on';
    final response = await _getText(url);
    return _parseSearchBooksResponse(response);
  }

  SearchByNameResponse _parseSearchBooksResponse(String html) {
    final doc = parse(html);
    final books = <SearchBookItem>[];
    final main = doc.querySelector('#main');
    if (main == null) return SearchByNameResponse(books: books);

    final resultsUl = _findResultsUl(main, '/b/');
    if (resultsUl == null) return SearchByNameResponse(books: books);

    for (final li in resultsUl.children) {
      if (li.localName != 'li') continue;
      final links = li.querySelectorAll('a');
      if (links.isEmpty) continue;
      final bookLink = links.first;
      final href = bookLink.attributes['href'] ?? '';
      final id = _extractId(href, '/b/');
      final name = bookLink.text.trim();
      if (id != null && name.isNotEmpty) {
        final authors = <SearchAuthorItem>[];
        for (final a in links.skip(1)) {
          final aHref = a.attributes['href'] ?? '';
          final aId = _extractId(aHref, '/a/');
          if (aId != null) {
            authors.add(SearchAuthorItem(id: aId, name: a.text.trim()));
          }
        }
        books.add(SearchBookItem(id: id, name: name, authors: authors));
      }
    }

    return SearchByNameResponse(books: books);
  }

  // ── Search: Books (OPDS) ────────────────────────────────────────────────────

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

  SearchByNameResponse _parseOpdsSearchResponse(String xml) {
    final doc = parse(xml);
    final books = <SearchBookItem>[];
    for (final entry in doc.querySelectorAll('entry')) {
      final id = _extractOpdsBookId(entry);
      final title = entry.querySelector('title')?.text.trim() ?? '';
      if (id != null && title.isNotEmpty) {
        final authors = <SearchAuthorItem>[];
        for (final authorEl in entry.querySelectorAll('author')) {
          final aName = authorEl.querySelector('name')?.text.trim() ?? '';
          final aUri = authorEl.querySelector('uri')?.text.trim() ?? '';
          final aId = _extractId(aUri, '/a/');
          if (aName.isNotEmpty) {
            authors.add(SearchAuthorItem(id: aId ?? '', name: aName));
          }
        }
        books.add(SearchBookItem(id: id, name: title, authors: authors));
      }
    }
    return SearchByNameResponse(books: books);
  }

  // ── Search: Authors (HTML) ──────────────────────────────────────────────────

  Future<SearchAuthorsResponse> searchAuthors(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&cha=on';
    final response = await _getText(url);
    return _parseSearchAuthorsResponse(response);
  }

  SearchAuthorsResponse _parseSearchAuthorsResponse(String html) {
    final doc = parse(html);
    final authors = <SearchAuthorItem>[];
    final main = doc.querySelector('#main');
    if (main == null) return SearchAuthorsResponse(authors: authors);

    final resultsUl = _findResultsUl(main, '/a/');
    if (resultsUl == null) return SearchAuthorsResponse(authors: authors);

    for (final li in resultsUl.children) {
      if (li.localName != 'li') continue;
      final link = li.querySelector('a[href^="/a/"]');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final id = _extractDigits(href);
      final name = link.text.trim();
      if (id != null && name.isNotEmpty) {
        authors.add(SearchAuthorItem(id: id, name: name));
      }
    }

    return SearchAuthorsResponse(authors: authors);
  }

  // ── Search: Series (HTML) ───────────────────────────────────────────────────

  Future<SearchSeriesResponse> searchBooksBySeries(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chs=on';
    final response = await _getText(url);
    return _parseSearchSeriesResponse(response);
  }

  SearchSeriesResponse _parseSearchSeriesResponse(String html) {
    final doc = parse(html);
    final series = <SearchSeriesItem>[];
    final main = doc.querySelector('#main');
    if (main == null) return SearchSeriesResponse(series: series);

    Element? resultsUl;
    for (final ul in main.querySelectorAll('ul')) {
      if (ul.querySelectorAll('a[href*="/sequence/"]').isNotEmpty) {
        resultsUl = ul;
        break;
      }
    }
    if (resultsUl == null) return SearchSeriesResponse(series: series);

    for (final li in resultsUl.children) {
      if (li.localName != 'li') continue;
      final link = li.querySelector('a[href*="/sequence/"]');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final id = _extractDigits(href);
      final name = link.text.trim();
      if (id != null && name.isNotEmpty) {
        series.add(SearchSeriesItem(id: id, name: name));
      }
    }

    return SearchSeriesResponse(series: series);
  }

  // ── Search: Genres (HTML) ───────────────────────────────────────────────────

  Future<SearchGenresResponse> searchGenres(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chg=on';
    final response = await _getText(url);
    return _parseSearchGenresResponse(response);
  }

  SearchGenresResponse _parseSearchGenresResponse(String html) {
    final doc = parse(html);
    final genres = <SearchGenreItem>[];
    final main = doc.querySelector('#main');
    if (main == null) return SearchGenresResponse(genres: genres);

    final resultsUl = _findResultsUl(main, '/g/');
    if (resultsUl == null) return SearchGenresResponse(genres: genres);

    for (final li in resultsUl.children) {
      if (li.localName != 'li') continue;
      final link = li.querySelector('a[href^="/g/"]');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final id = href.replaceFirst('/g/', '');
      final name = link.text.trim();
      if (id.isNotEmpty && name.isNotEmpty) {
        genres.add(SearchGenreItem(id: id, name: name));
      }
    }

    return SearchGenresResponse(genres: genres);
  }

  // ── Book Details (HTML) ─────────────────────────────────────────────────────

  Future<BookDetailsResponse> getBookDetails(String bookId) async {
    final response = await _getText('b/$bookId');
    return _parseBookDetailsResponse(response, bookId);
  }

  BookDetailsResponse _parseBookDetailsResponse(String html, String bookId) {
    final doc = parse(html);

    // Title: skip first h1 ("Флибуста" site name), use the second
    String title = '';
    final h1Tags = doc.querySelectorAll('h1');
    for (final h1 in h1Tags) {
      final text = h1.text.trim();
      if (text.isNotEmpty && text != 'Флибуста') {
        title = text;
        break;
      }
    }

    // Description: find h2 "Аннотация:" and collect sibling text
    String description = '';
    for (final h2 in doc.querySelectorAll('h2')) {
      if (h2.text.contains('Аннотация')) {
        final parts = <String>[];
        Element? sibling = h2.nextElementSibling;
        while (sibling != null && sibling.localName != 'h2') {
          parts.add(sibling.text.trim());
          sibling = sibling.nextElementSibling;
        }
        description = parts.join(' ');
        break;
      }
    }

    // Cover: img with "cover" in src
    final coverImg = doc.querySelector('img[src*="cover"]');
    final coverUrl = coverImg?.attributes['src'];

    // Find the book info container (div with the title h1)
    Element? bookInfoDiv;
    for (final div in doc.querySelectorAll('div')) {
      final h1 = div.querySelector('h1');
      if (h1 != null && title.isNotEmpty && h1.text.contains(title)) {
        bookInfoDiv = div;
        break;
      }
    }

    // Authors: /a/ links BEFORE download links
    final authors = <String>[];
    final seenAuthorIds = <String>{};
    if (bookInfoDiv != null) {
      bool foundDownload = false;
      for (final a in bookInfoDiv.querySelectorAll('a[href]')) {
        final href = a.attributes['href'] ?? '';
        if (href.startsWith('/b/') &&
            (href.contains('/download') ||
                href.endsWith('/read') ||
                href.endsWith('/fb2') ||
                href.endsWith('/epub') ||
                href.endsWith('/mobi') ||
                href.endsWith('/txt') ||
                href.endsWith('/pdf'))) {
          foundDownload = true;
          continue;
        }
        if (foundDownload) break;
        if (href.startsWith('/a/')) {
          final authorId = _extractDigits(href);
          if (authorId != null && seenAuthorIds.add(authorId)) {
            authors.add(a.text.trim());
          }
        }
      }
    }
    // Fallback: all /a/ links if no bookInfoDiv found
    if (authors.isEmpty) {
      for (final a in doc.querySelectorAll('a[href^="/a/"]')) {
        final name = a.text.trim();
        if (name.isNotEmpty) authors.add(name);
      }
    }

    // Genres: /g/ links BEFORE download links
    final genreIds = <String>[];
    if (bookInfoDiv != null) {
      bool foundDownload = false;
      for (final a in bookInfoDiv.querySelectorAll('a[href]')) {
        final href = a.attributes['href'] ?? '';
        if (href.startsWith('/b/') &&
            (href.endsWith('/read') ||
                href.endsWith('/fb2') ||
                href.endsWith('/epub') ||
                href.endsWith('/mobi') ||
                href.endsWith('/txt') ||
                href.endsWith('/pdf'))) {
          foundDownload = true;
          continue;
        }
        if (foundDownload) break;
        if (href.startsWith('/g/')) {
          genreIds.add(href.replaceFirst('/g/', ''));
        }
      }
    }

    // Download formats: /b/{id}/{format} links
    final formats = <String>[];
    final seenFormats = <String>{};
    for (final a in doc.querySelectorAll('a[href^="/b/$bookId/"]')) {
      final href = a.attributes['href'] ?? '';
      final fmtMatch = RegExp(r'/b/\d+/(\w+)$').firstMatch(href);
      if (fmtMatch != null) {
        final fmt = fmtMatch.group(1)!;
        if (fmt == 'read' || fmt == 'download' || fmt == 'mail' || fmt == 'complain') continue;
        if (seenFormats.add(fmt)) formats.add(fmt);
      }
    }

    // Series: /sequence/ or /s/ links in book info div
    final seriesList = <SeriesInfoItem>[];
    if (bookInfoDiv != null) {
      for (final a in bookInfoDiv.querySelectorAll('a[href]')) {
        final href = a.attributes['href'] ?? '';
        if (href.contains('/sequence/') || href.startsWith('/s/')) {
          final sId = _extractDigits(href);
          if (sId != null) {
            seriesList.add(SeriesInfoItem(id: sId, name: a.text.trim()));
          }
        }
      }
    }

    return BookDetailsResponse(
      id: bookId,
      title: title,
      description: description,
      coverUrl: coverUrl,
      authors: authors,
      formats: formats,
      genres: genreIds,
      series: seriesList,
    );
  }

  Future<String> getDownloadUrl(String bookId, String format) async {
    final base = _dio.options.baseUrl;
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$normalizedBase/b/$bookId/$format';
  }

  // ── Recent Books (HTML) ─────────────────────────────────────────────────────

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

  RecentBooksResponse _parseRecentBooksResponse(String html) {
    final doc = parse(html);
    final books = <SearchBookItem>[];
    final seen = <String>{};
    final main = doc.querySelector('#main') ?? doc;

    for (final a in main.querySelectorAll('a[href^="/b/"]')) {
      final href = a.attributes['href'] ?? '';
      final id = _extractId(href, '/b/');
      final name = a.text.trim();
      if (id != null && name.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return RecentBooksResponse(books: books);
  }

  // ── Author Detail (HTML) ────────────────────────────────────────────────────

  Future<AuthorDetailResponse> getAuthorDetail(String authorId) async {
    final response = await _getText('a/$authorId');
    return _parseAuthorDetailResponse(response, authorId);
  }

  AuthorDetailResponse _parseAuthorDetailResponse(String html, String authorId) {
    final doc = parse(html);

    // Name: skip first h1 ("Флибуста")
    String name = '';
    final h1Tags = doc.querySelectorAll('h1');
    for (final h1 in h1Tags) {
      final text = h1.text.trim();
      if (text.isNotEmpty && text != 'Флибуста') {
        name = text;
        break;
      }
    }

    final books = <SearchBookItem>[];
    final seen = <String>{};
    final main = doc.querySelector('#main') ?? doc;

    for (final a in main.querySelectorAll('a[href^="/b/"]')) {
      final href = a.attributes['href'] ?? '';
      final id = _extractId(href, '/b/');
      final bookName = a.text.trim();
      if (id != null && bookName.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: bookName));
      }
    }

    return AuthorDetailResponse(id: authorId, name: name, books: books);
  }

  // ── Genre Books (HTML) ──────────────────────────────────────────────────────

  Future<GenreBooksResponse> getGenreBooks(
    String genreId, {
    String order = 'a',
  }) async {
    final response = await _getText('g/$genreId?order=$order');
    return _parseGenreBooksResponse(response, genreId);
  }

  GenreBooksResponse _parseGenreBooksResponse(String html, String genreId) {
    final doc = parse(html);

    String name = '';
    final h1Tags = doc.querySelectorAll('h1');
    for (final h1 in h1Tags) {
      final text = h1.text.trim();
      if (text.isNotEmpty && text != 'Флибуста') {
        name = text;
        break;
      }
    }

    final books = <SearchBookItem>[];
    final seen = <String>{};
    final main = doc.querySelector('#main') ?? doc;

    for (final a in main.querySelectorAll('a[href^="/b/"]')) {
      final href = a.attributes['href'] ?? '';
      final id = _extractId(href, '/b/');
      final bookName = a.text.trim();
      if (id != null && bookName.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: bookName));
      }
    }

    return GenreBooksResponse(id: genreId, name: name, books: books);
  }

  // ── Genre List (HTML from /g) ───────────────────────────────────────────────

  Future<GenreListResponse> getGenreList() async {
    final response = await _getText('g');
    return _parseGenreListResponse(response);
  }

  GenreListResponse _parseGenreListResponse(String html) {
    final doc = parse(html);
    final genres = <SearchGenreItem>[];
    final seen = <String>{};

    for (final a in doc.querySelectorAll('a[href^="/g/"]')) {
      final href = a.attributes['href'] ?? '';
      final id = href.replaceFirst('/g/', '');
      final name = a.text.trim();
      if (id.isNotEmpty && name.isNotEmpty && seen.add(id)) {
        genres.add(SearchGenreItem(id: id, name: name));
      }
    }

    return GenreListResponse(genres: genres);
  }

  // ── Series Detail (HTML) ────────────────────────────────────────────────────

  Future<SeriesDetailResponse> getSeriesDetail(String seriesId) async {
    final response = await _getText('sequence/$seriesId');
    return _parseSeriesDetailResponse(response, seriesId);
  }

  SeriesDetailResponse _parseSeriesDetailResponse(String html, String seriesId) {
    final doc = parse(html);

    String name = '';
    final h1Tags = doc.querySelectorAll('h1');
    for (final h1 in h1Tags) {
      final text = h1.text.trim();
      if (text.isNotEmpty && text != 'Флибуста') {
        name = text;
        break;
      }
    }

    final books = <SearchBookItem>[];
    final seen = <String>{};
    final main = doc.querySelector('#main') ?? doc;

    for (final a in main.querySelectorAll('a[href^="/b/"]')) {
      final href = a.attributes['href'] ?? '';
      final id = _extractId(href, '/b/');
      final bookName = a.text.trim();
      if (id != null && bookName.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: bookName));
      }
    }

    return SeriesDetailResponse(id: seriesId, name: name, books: books);
  }

  // ── OPDS: Popular/Recent books ──────────────────────────────────────────────

  Future<OpdsBooksResponse> getPopularBooksOpds({int page = 0}) async {
    final response = await _getText('opds/popular?pageNumber=$page');
    return _parseOpdsBooksResponse(response);
  }

  Future<OpdsBooksResponse> getRecentBooksOpds({int page = 0}) async {
    final response = await _getText('opds/recent?pageNumber=$page');
    return _parseOpdsBooksResponse(response);
  }

  OpdsBooksResponse _parseOpdsBooksResponse(String xml) {
    final doc = parse(xml);
    final books = <SearchBookItem>[];

    for (final entry in doc.querySelectorAll('entry')) {
      final id = _extractOpdsBookId(entry);
      final title = entry.querySelector('title')?.text.trim() ?? '';
      if (id != null && title.isNotEmpty) {
        final authors = <SearchAuthorItem>[];
        for (final authorEl in entry.querySelectorAll('author')) {
          final aName = authorEl.querySelector('name')?.text.trim() ?? '';
          if (aName.isNotEmpty) {
            authors.add(SearchAuthorItem(id: '', name: aName));
          }
        }
        books.add(SearchBookItem(id: id, name: title, authors: authors));
      }
    }

    return OpdsBooksResponse(books: books);
  }

  // ── OPDS: Genres ────────────────────────────────────────────────────────────

  Future<OpdsGenresResponse> getGenresOpds() async {
    final response = await _getText('opds/genres');
    return _parseOpdsGenresResponse(response);
  }

  OpdsGenresResponse _parseOpdsGenresResponse(String xml) {
    final doc = parse(xml);
    final genres = <SearchGenreItem>[];

    for (final entry in doc.querySelectorAll('entry')) {
      final idEl = entry.querySelector('id');
      final titleEl = entry.querySelector('title');
      if (idEl == null || titleEl == null) continue;

      final rawId = idEl.text.trim();
      final genreId = rawId.contains('/g/') ? rawId.split('/g/').last : rawId;
      final name = titleEl.text.trim();
      if (genreId.isNotEmpty && name.isNotEmpty) {
        genres.add(SearchGenreItem(id: genreId, name: name));
      }
    }

    return OpdsGenresResponse(genres: genres);
  }

  // ── Bookshelf (Polka) ───────────────────────────────────────────────────────

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
    try {
      final base = _dio.options.baseUrl;
      final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final response = await _dio.get<String>(
        '$normalizedBase/polka/watch/add/$bookId',
        options: Options(responseType: ResponseType.plain),
      );
      return response.statusCode == 200 && !(response.data?.contains('user/login') ?? false);
    } on Object {
      return false;
    }
  }

  // ── Messages ────────────────────────────────────────────────────────────────

  Future<MessagesResponse> getMessages() async {
    final response = await _getText('messages');
    return _parseMessagesResponse(response);
  }

  MessagesResponse _parseMessagesResponse(String html) {
    final doc = parse(html);
    final messages = <MessageItem>[];

    for (final tr in doc.querySelectorAll('tr')) {
      final cells = tr.querySelectorAll('td');
      if (cells.length >= 3) {
        final sender = cells[0].text.trim();
        final subject = cells[1].text.trim();
        final date = cells[2].text.trim();
        if (sender.isNotEmpty || subject.isNotEmpty) {
          messages.add(MessageItem(sender: sender, subject: subject, date: date));
        }
      }
    }

    return MessagesResponse(messages: messages);
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

  // ── User Profile ────────────────────────────────────────────────────────────

  Future<UserProfileResponse> getUserProfile(String userId) async {
    final response = await _getText('user/$userId');
    return _parseUserProfileResponse(response, userId);
  }

  UserProfileResponse _parseUserProfileResponse(String html, String userId) {
    final doc = parse(html);
    final title = doc.querySelector('title')?.text.trim() ?? '';
    final username = title.replaceAll(' | Флибуста', '').trim();
    return UserProfileResponse(
      userId: userId,
      username: username.isNotEmpty ? username : 'User #$userId',
    );
  }

  // ── Recommendations ─────────────────────────────────────────────────────────

  Future<RecommendationsResponse> getRecommendations({String? userId}) async {
    final url = userId != null ? 'rec?view=recs&user=$userId' : 'rec';
    final response = await _getText(url);
    return _parseRecommendationsResponse(response);
  }

  RecommendationsResponse _parseRecommendationsResponse(String html) {
    final books = _extractBookLinks(html);
    return RecommendationsResponse(books: books);
  }

  // ── Black/White List ────────────────────────────────────────────────────────

  Future<BwListResponse> getBwList(String userId) async {
    final response = await _getText('bwlist/show/$userId');
    return _parseBwListResponse(response, userId);
  }

  BwListResponse _parseBwListResponse(String html, String userId) {
    final books = _extractBookLinks(html);
    return BwListResponse(userId: userId, books: books);
  }

  // ── Tracker ─────────────────────────────────────────────────────────────────

  Future<TrackerResponse> getTracker() async {
    final response = await _getText('tracker');
    return _parseTrackerResponse(response);
  }

  TrackerResponse _parseTrackerResponse(String html) {
    final books = _extractBookLinks(html);
    return TrackerResponse(books: books);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Element? _findResultsUl(Element container, String linkPrefix) {
    for (final ul in container.querySelectorAll('ul')) {
      if (ul.querySelectorAll('a[href^="$linkPrefix"]').isNotEmpty) {
        return ul;
      }
    }
    return null;
  }

  String? _extractId(String href, String prefix) {
    if (!href.startsWith(prefix)) return null;
    final remainder = href.substring(prefix.length);
    final match = RegExp(r'^(\d+)').firstMatch(remainder);
    return match?.group(1);
  }

  String? _extractDigits(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match?.group(1);
  }

  String? _extractOpdsBookId(Element entry) {
    final idEl = entry.querySelector('id');
    if (idEl == null) return null;
    final raw = idEl.text.trim();
    final match = RegExp(r'/b/(\d+)').firstMatch(raw);
    return match?.group(1);
  }

  List<SearchBookItem> _extractBookLinks(String html) {
    final doc = parse(html);
    final books = <SearchBookItem>[];
    final seen = <String>{};
    final main = doc.querySelector('#main') ?? doc;

    for (final a in main.querySelectorAll('a[href^="/b/"]')) {
      final href = a.attributes['href'] ?? '';
      final id = _extractId(href, '/b/');
      final name = a.text.trim();
      if (id != null && name.isNotEmpty && seen.add(id)) {
        books.add(SearchBookItem(id: id, name: name));
      }
    }

    return books;
  }
}

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
  final List<String> formats;
  final List<String> genres;
  final List<SeriesInfoItem> series;

  const BookDetailsResponse({
    required this.id,
    required this.title,
    required this.description,
    this.coverUrl,
    required this.authors,
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

import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' show parse;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/http/http_client.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';
import 'flibusta_models.dart';

part 'flibusta_source.g.dart';

@riverpod
FlibustaHtmlSource flibustaSource(Ref ref) {
  final client = ref.watch(httpClientProvider);
  return FlibustaHtmlSource(client);
}

class FlibustaHtmlSource extends BookSource {
  final HttpClient client;
  final String sourceId;

  FlibustaHtmlSource(this.client) : sourceId = Uri.parse(client.dio.options.baseUrl).host;

  Dio get dio => client.dio;

  // ── BookSource interface ──────────────────────────────────────────────────

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) async {
    if (query.query.isEmpty) {
      return SearchResultPage(
        books: const [],
        totalCount: 0,
        currentPage: query.page,
        totalPages: 0,
        hasNextPage: false,
      );
    }
    final searchUrl = _buildSearchUrl(query);
    final html = await client.getWithMirror(searchUrl, cancelToken: cancelToken);
    return _parseSearchResults(html, query);
  }

  @override
  Future<SearchAuthorsResultPage> searchAuthors(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (query.query.isEmpty) {
      return const SearchAuthorsResultPage(authors: []);
    }
    final params = <String>[
      'ask=${Uri.encodeComponent(query.query)}',
      'page=${query.page}',
      'cha=on',
    ];
    final searchUrl = '/booksearch?${params.join('&')}';
    final html = await client.getWithMirror(searchUrl, cancelToken: cancelToken);
    return _parseAuthorSearchResults(html);
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    final html = await client.getWithMirror('/b/$bookId');
    return _parseBookDetails(html, bookId);
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    final details = await getBookDetails(bookId);
    return details.availableFormats;
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    final rawBase = client.dio.options.baseUrl;
    final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
    return '$base/b/$bookId/${format.name}';
  }

  // ── Genre List ────────────────────────────────────────────────────────────

  Future<GenreListResponse> getGenreList({CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('g', cancelToken: cancelToken);
    return _parseGenreListResponse(html);
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

  // ── Genre Books ───────────────────────────────────────────────────────────

  Future<GenreBooksResponse> getGenreBooks(
    String genreId, {
    String order = 'a',
    CancelToken? cancelToken,
  }) async {
    final html = await client.getWithMirror(
      'g/$genreId?order=$order',
      cancelToken: cancelToken,
    );
    return _parseGenreBooksResponse(html, genreId);
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

  // ── Popular Books ─────────────────────────────────────────────────────────

  Future<OpdsBooksResponse> getPopularBooks({CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('stat/b', cancelToken: cancelToken);
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

    return OpdsBooksResponse(books: books);
  }

  // ── Recent Books ──────────────────────────────────────────────────────────

  Future<RecentBooksResponse> getRecentBooks({
    String? lang,
    String? type,
    CancelToken? cancelToken,
  }) async {
    final params = <String>[];
    if (lang != null) params.add('lang=$lang');
    if (type != null) params.add('type=$type');
    final url = 'new${params.isNotEmpty ? '?${params.join('&')}' : ''}';
    final html = await client.getWithMirror(url, cancelToken: cancelToken);
    return _parseRecentBooksResponse(html);
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

  // ── Author Detail ─────────────────────────────────────────────────────────

  Future<AuthorDetailResponse> getAuthorDetail(String authorId, {CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('a/$authorId', cancelToken: cancelToken);
    return _parseAuthorDetailResponse(html, authorId);
  }

  AuthorDetailResponse _parseAuthorDetailResponse(String html, String authorId) {
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

    String? avatarUrl;
    final divabio = doc.querySelector('#divabio');
    if (divabio != null) {
      for (final img in divabio.querySelectorAll('img')) {
        final src = img.attributes['src'] ?? '';
        if (src.contains('/ia/')) {
          avatarUrl = src;
          break;
        }
      }
    }

    String biography = '';
    if (divabio != null) {
      final parts = <String>[];
      for (final p in divabio.querySelectorAll('p')) {
        final text = p.text.trim();
        if (text.isNotEmpty && !text.startsWith('http')) {
          parts.add(text);
        }
      }
      biography = parts.join('\n\n');
    }

    Element? booksForm;
    for (final form in doc.querySelectorAll('form')) {
      final method = (form.attributes['method'] ?? '').toUpperCase();
      if (method == 'POST' && form.innerHtml.contains('/b/')) {
        booksForm = form;
        break;
      }
    }

    final seriesGroups = <AuthorSeriesGroup>[];
    final allBooks = <SearchBookItem>[];
    final seenBookIds = <String>{};

    if (booksForm != null) {
      AuthorSeriesGroup? currentSeries;

      for (final child in booksForm.nodes) {
        if (child is! Element) continue;

        if (child.localName == 'a') {
          final href = child.attributes['href'] ?? '';
          final seriesMatch = RegExp(r'^/s/(\d+)$').firstMatch(href);
          if (seriesMatch != null) {
            final seriesId = seriesMatch.group(1)!;
            final h8 = child.querySelector('span.h8');
            final seriesName = h8?.text.trim() ?? child.text.trim();

            final genres = <AuthorGenreItem>[];
            Element? sibling = child.nextElementSibling;
            while (sibling != null) {
              if (sibling.localName == 'br') break;
              if (sibling.localName == 'a') {
                final ghref = sibling.attributes['href'] ?? '';
                final gidMatch = RegExp(r'^/g/(\d+)$').firstMatch(ghref);
                if (gidMatch != null) {
                  genres.add(
                    AuthorGenreItem(
                      id: gidMatch.group(1)!,
                      name: sibling.text.trim(),
                    ),
                  );
                }
              }
              sibling = sibling.nextElementSibling;
            }

            currentSeries = AuthorSeriesGroup(
              id: seriesId,
              name: seriesName,
              genres: genres,
            );
            seriesGroups.add(currentSeries);
            continue;
          }

          final bookMatch = RegExp(r'^/b/(\d+)$').firstMatch(href);
          if (bookMatch != null) {
            final bookId = bookMatch.group(1)!;
            final bookName = child.text.trim();
            if (bookName.isEmpty) continue;

            double? rating;
            Element? prev = child.previousElementSibling;
            for (var k = 0; k < 10 && prev != null; k++) {
              if (prev.localName == 'svg') {
                final svgText = prev.text.trim();
                final r = double.tryParse(svgText);
                if (r != null && r > 0) rating = r;
                break;
              }
              prev = prev.previousElementSibling;
            }

            final formats = <String>[];
            Element? next = child.nextElementSibling;
            for (var k = 0; k < 15 && next != null; k++) {
              if (next.localName == 'br') break;
              if (next.localName == 'a') {
                final ahref = next.attributes['href'] ?? '';
                final fmtMatch = RegExp('^/b/$bookId/(\\w+)\$').firstMatch(ahref);
                if (fmtMatch != null) {
                  final fmt = fmtMatch.group(1)!;
                  if (fmt != 'read' && fmt != 'download' && fmt != 'mail' && fmt != 'complain') {
                    formats.add(fmt);
                  }
                }
              }
              next = next.nextElementSibling;
            }

            if (seenBookIds.add(bookId)) {
              final bookItem = SearchBookItem(id: bookId, name: bookName);
              allBooks.add(bookItem);
              currentSeries?.books.add(
                AuthorBookItem(
                  id: bookId,
                  name: bookName,
                  rating: rating,
                  formats: formats,
                ),
              );
            }
          }
        }
      }
    }

    if (allBooks.isEmpty) {
      final main = doc.querySelector('#main') ?? doc;
      for (final a in main.querySelectorAll('a[href^="/b/"]')) {
        final href = a.attributes['href'] ?? '';
        final id = _extractId(href, '/b/');
        final bookName = a.text.trim();
        if (id != null && bookName.isNotEmpty && seenBookIds.add(id)) {
          allBooks.add(SearchBookItem(id: id, name: bookName));
        }
      }
    }

    return AuthorDetailResponse(
      id: authorId,
      name: name,
      avatarUrl: avatarUrl,
      biography: biography,
      seriesGroups: seriesGroups,
      books: allBooks,
    );
  }

  // ── Series Detail ─────────────────────────────────────────────────────────

  Future<SeriesDetailResponse> getSeriesDetail(String seriesId, {CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('sequence/$seriesId', cancelToken: cancelToken);
    return _parseSeriesDetailResponse(html, seriesId);
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

  // ── Bookshelf (Polka) ─────────────────────────────────────────────────────

  Future<bool> addToBookshelf(
    String bookId, {
    String? review,
    int? score,
    CancelToken? cancelToken,
  }) async {
    final data = <String, String>{
      'flag': 'on',
      'op': 'Сохранить',
    };
    if (review != null) data['body'] = review;
    if (score != null) data['score'] = score.toString();
    final response = await client.dio.post<String>(
      'polka/add/$bookId',
      data: data,
      options: Options(contentType: 'application/x-www-form-urlencoded'),
      cancelToken: cancelToken,
    );
    return response.statusCode == 200;
  }

  Future<bool> watchBook(String bookId, {CancelToken? cancelToken}) async {
    try {
      final base = client.dio.options.baseUrl;
      final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final response = await client.dio.get<String>(
        '$normalizedBase/polka/watch/add/$bookId',
        options: Options(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
      return response.statusCode == 200 && !(response.data?.contains('user/login') ?? false);
    } on DioException catch (_) {
      return false;
    } on Object catch (_) {
      return false;
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<MessagesResponse> getMessages({CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('messages', cancelToken: cancelToken);
    return _parseMessagesResponse(html);
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
    String body, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.dio.post<String>(
      'messages/new',
      data: <String, String>{
        'recipient': recipient,
        'subject': subject,
        'body': body,
        'op': 'Отправить сообщение',
      },
      options: Options(contentType: 'application/x-www-form-urlencoded'),
      cancelToken: cancelToken,
    );
    return response.statusCode == 200 || response.statusCode == 302;
  }

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<UserProfileResponse> getUserProfile(String userId, {CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('user/$userId', cancelToken: cancelToken);
    return _parseUserProfileResponse(html, userId);
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

  // ── Recommendations ───────────────────────────────────────────────────────

  Future<RecommendationsResponse> getRecommendations({
    String? userId,
    CancelToken? cancelToken,
  }) async {
    final url = userId != null ? 'rec?view=recs&user=$userId' : 'rec';
    final html = await client.getWithMirror(url, cancelToken: cancelToken);
    return RecommendationsResponse(books: _extractBookLinks(html));
  }

  // ── Black/White List ──────────────────────────────────────────────────────

  Future<BwListResponse> getBwList(String userId, {CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('bwlist/show/$userId', cancelToken: cancelToken);
    return BwListResponse(userId: userId, books: _extractBookLinks(html));
  }

  // ── Tracker ───────────────────────────────────────────────────────────────

  Future<TrackerResponse> getTracker({CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('tracker', cancelToken: cancelToken);
    return TrackerResponse(books: _extractBookLinks(html));
  }

  // ── OPDS ──────────────────────────────────────────────────────────────────

  Future<OpdsBooksResponse> getPopularBooksOpds({int page = 0, CancelToken? cancelToken}) async {
    final html = await client.getWithMirror(
      'opds/popular?pageNumber=$page',
      cancelToken: cancelToken,
    );
    return _parseOpdsBooksResponse(html);
  }

  Future<OpdsBooksResponse> getRecentBooksOpds({int page = 0, CancelToken? cancelToken}) async {
    final html = await client.getWithMirror(
      'opds/recent?pageNumber=$page',
      cancelToken: cancelToken,
    );
    return _parseOpdsBooksResponse(html);
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

  Future<OpdsGenresResponse> getGenresOpds({CancelToken? cancelToken}) async {
    final html = await client.getWithMirror('opds/genres', cancelToken: cancelToken);
    return _parseOpdsGenresResponse(html);
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

  // ── Search Parsing Helpers ────────────────────────────────────────────────

  String _buildSearchUrl(SearchQuery query) {
    final params = <String>[];
    params.add('ask=${Uri.encodeComponent(query.query)}');
    params.add('page=${query.page}');
    params.add('chb=on');
    return '/booksearch?${params.join('&')}';
  }

  SearchResultPage _parseSearchResults(String html, SearchQuery query) {
    final document = parse(html);
    final books = <Book>[];

    final main = document.querySelector('#main');
    if (main == null) {
      return SearchResultPage(
        books: const [],
        totalCount: 0,
        currentPage: query.page,
        totalPages: 0,
        hasNextPage: false,
      );
    }

    Element? resultsUl;
    for (final ul in main.querySelectorAll('ul')) {
      final links = ul.querySelectorAll('a[href^="/b/"]');
      if (links.isNotEmpty) {
        resultsUl = ul;
        break;
      }
    }

    if (resultsUl != null) {
      final rawBase = client.dio.options.baseUrl;
      final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;

      for (final li in resultsUl.children) {
        if (li.localName != 'li') continue;
        final links = li.querySelectorAll('a');
        if (links.isEmpty) continue;

        final bookLink = links.first;
        final href = bookLink.attributes['href'] ?? '';
        final idMatch = RegExp(r'/b/(\d+)').firstMatch(href);
        if (idMatch == null) continue;

        final bookId = idMatch.group(1)!;
        final bookName = bookLink.text.trim();
        if (bookName.isEmpty) continue;

        final authorLinks = links.skip(1).where((a) {
          final h = a.attributes['href'] ?? '';
          return h.startsWith('/a/');
        });
        final authorNames = authorLinks
            .map((a) => a.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        final authorIds = authorLinks
            .map((a) {
              final h = a.attributes['href'] ?? '';
              final m = RegExp(r'/a/(\d+)').firstMatch(h);
              return m?.group(1) ?? '';
            })
            .where((id) => id.isNotEmpty)
            .toList();

        books.add(
          Book(
            id: bookId,
            title: bookName,
            authorIds: authorIds,
            authorNames: authorNames,
            genreIds: const [],
            description: null,
            coverUrl: null,
            publishDate: null,
            availableFormats: const [],
            source: BookSourceInfo(sourceId: sourceId, sourceUrl: '$base/b/$bookId'),
          ),
        );
      }
    }

    final pageInfo = _parsePagination(document);
    final totalCount = _parseTotalCount(document);
    final hasNextPage = pageInfo['has_next'] as bool? ?? false;

    return SearchResultPage(
      books: books,
      totalCount: totalCount ?? books.length,
      currentPage: query.page,
      totalPages: pageInfo['total_pages'] as int? ?? 1,
      hasNextPage: hasNextPage,
    );
  }

  SearchAuthorsResultPage _parseAuthorSearchResults(String html) {
    final document = parse(html);
    final authors = <SearchAuthorResult>[];

    final main = document.querySelector('#main');
    if (main == null) {
      return const SearchAuthorsResultPage(authors: []);
    }

    Element? resultsUl;
    for (final ul in main.querySelectorAll('ul')) {
      final links = ul.querySelectorAll('a[href^="/a/"]');
      if (links.isNotEmpty) {
        resultsUl = ul;
        break;
      }
    }

    if (resultsUl != null) {
      for (final li in resultsUl.children) {
        if (li.localName != 'li') continue;
        final link = li.querySelector('a[href^="/a/"]');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';
        final idMatch = RegExp(r'/a/(\d+)').firstMatch(href);
        if (idMatch == null) continue;
        final id = idMatch.group(1)!;
        final name = link.text.trim();
        if (name.isNotEmpty) {
          authors.add(SearchAuthorResult(id: id, name: name));
        }
      }
    }

    return SearchAuthorsResultPage(authors: authors);
  }

  Map<String, dynamic> _parsePagination(Document document) {
    final pager = document.querySelector('div.item-list .pager');
    if (pager == null) {
      return {'total_pages': 1, 'has_next': false, 'has_previous': false};
    }

    final pagerItems = pager.querySelectorAll('[class*="pager-current"], [class*="pager-item"]');
    final hasNext = pager.querySelector('.pager-next') != null;
    final hasPrevious = pager.querySelector('.pager-previous') != null;

    int totalPages = 1;
    for (final item in pagerItems) {
      final text = item.text.trim();
      final pageNum = int.tryParse(text);
      if (pageNum != null && pageNum > totalPages) {
        totalPages = pageNum;
      }
    }

    return {
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }

  int? _parseTotalCount(Document document) {
    final h3 = document.querySelector('h3');
    if (h3 == null) return null;
    final text = h3.text;
    final match = RegExp(r'из\s+(\d+)').firstMatch(text);
    return match != null ? int.tryParse(match.group(1) ?? '') : null;
  }

  BookDetails _parseBookDetails(String html, String bookId) {
    final document = parse(html);

    String title = '';
    final h1Tags = document.querySelectorAll('h1');
    for (final h1 in h1Tags) {
      final text = h1.text.trim();
      if (text.isNotEmpty && text != 'Флибуста') {
        title = text;
        break;
      }
    }

    String description = '';
    for (final h2 in document.querySelectorAll('h2')) {
      if (h2.text.contains('Аннотация')) {
        final parts = <String>[];
        for (
          var sibling = h2.nextElementSibling;
          sibling != null && sibling.localName != 'h2';
          sibling = sibling.nextElementSibling
        ) {
          if (sibling.localName == 'p' || sibling.localName == 'div') {
            parts.add(sibling.text.trim());
          }
        }
        description = parts.join(' ');
        break;
      }
    }

    final coverImg = document.querySelector('img[src*="cover"]');
    final coverUrl = coverImg?.attributes['src'];

    final authorElements = document.querySelectorAll('a[href^="/a/"]');
    final authors = authorElements.map((a) => a.text.trim()).where((t) => t.isNotEmpty).toList();
    final authorIds = authorElements
        .map((a) {
          final m = RegExp(r'/a/(\d+)').firstMatch(a.attributes['href'] ?? '');
          return m?.group(1) ?? '';
        })
        .where((id) => id.isNotEmpty)
        .toList();

    final genreElements = document.querySelectorAll('a[href^="/g/"]');
    final genreIds = genreElements
        .map((g) {
          final href = g.attributes['href'] ?? '';
          return href.replaceFirst('/g/', '');
        })
        .where((id) => id.isNotEmpty)
        .toList();

    final formats = <BookFormat>[];
    final downloadUrls = <String>[];
    final seenFormats = <String>{};
    final formatLinks = document.querySelectorAll('a[href^="/b/$bookId/"]');
    for (final link in formatLinks) {
      final href = link.attributes['href'] ?? '';
      final fmtMatch = RegExp(r'/b/\d+/(\w+)').firstMatch(href);
      if (fmtMatch != null) {
        final fmt = fmtMatch.group(1)!;
        if (fmt == 'read' || fmt == 'download' || fmt == 'mail' || fmt == 'complain') continue;
        final format = _parseFormat(fmt);
        if (format != null && seenFormats.add(fmt)) {
          formats.add(format);
        }
        if (!downloadUrls.contains(href)) {
          downloadUrls.add(href);
        }
      }
    }

    final rawBase = client.dio.options.baseUrl;
    final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;

    final book = Book(
      id: bookId,
      title: title,
      authorIds: authorIds,
      authorNames: authors,
      genreIds: genreIds,
      description: description.isNotEmpty ? description : null,
      coverUrl: coverUrl != null && coverUrl.isNotEmpty
          ? (coverUrl.startsWith('http') ? coverUrl : '$base$coverUrl')
          : null,
      publishDate: null,
      availableFormats: formats,
      source: BookSourceInfo(sourceId: sourceId, sourceUrl: '$base/b/$bookId'),
    );

    return BookDetails(
      book: book,
      description: description.isNotEmpty ? description : null,
      availableFormats: formats,
      downloadUrls: downloadUrls.map((u) => u.startsWith('/') ? '$base$u' : u).toList(),
    );
  }

  BookFormat? _parseFormat(String fmt) {
    switch (fmt.toLowerCase()) {
      case 'fb2':
        return BookFormat.fb2;
      case 'epub':
        return BookFormat.epub;
      case 'txt':
        return BookFormat.txt;
      case 'pdf':
        return BookFormat.pdf;
      case 'mobi':
      case 'azw':
        return BookFormat.mobi;
      case 'azw3':
        return BookFormat.azw3;
      case 'prc':
        return BookFormat.prc;
      case 'djvu':
        return BookFormat.djvu;
      case 'rtf':
        return BookFormat.rtf;
      case 'html':
        return BookFormat.unknown;
      default:
        return null;
    }
  }

  // ── Common Helpers ────────────────────────────────────────────────────────

  String? _extractId(String href, String prefix) {
    if (!href.startsWith(prefix)) return null;
    final remainder = href.substring(prefix.length);
    final match = RegExp(r'^(\d+)').firstMatch(remainder);
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

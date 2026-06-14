import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' show parse;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/http/http_client.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';
import 'flibusta_api_client.dart';

part 'flibusta_api_source.g.dart';

@riverpod
FlibustaApiSource flibustaApiSource(Ref ref) {
  final client = ref.watch(flibustaApiClientProvider);
  return FlibustaApiSource(client);
}

class FlibustaApiSource extends BookSource {
  final FlibustaApiClient _client;
  final HttpClient _httpClient;

  FlibustaApiSource(this._client) : _httpClient = _client.httpClient;

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) async {
    if (query.hasFilters) {
      return SearchResultPage(
        books: const [],
        totalCount: 0,
        currentPage: query.page,
        totalPages: 0,
        hasNextPage: false,
      );
    }

    final url = '/booksearch?ask=${Uri.encodeComponent(query.query)}&page=${query.page}&chb=on';
    final html = await _httpClient.getWithMirror(url, cancelToken: cancelToken);

    try {
      final doc = parse(html);
      final books = <Book>[];
      final main = doc.querySelector('#main');
      if (main != null) {
        Element? resultsUl;
        for (final ul in main.querySelectorAll('ul')) {
          final links = ul.querySelectorAll('a[href^="/b/"]');
          if (links.isNotEmpty) {
            resultsUl = ul;
            break;
          }
        }
        if (resultsUl != null) {
          for (final li in resultsUl.children) {
            if (li.localName != 'li') continue;
            final links = li.querySelectorAll('a');
            if (links.isEmpty) continue;
            final bookLink = links.first;
            final href = bookLink.attributes['href'] ?? '';
            final idMatch = RegExp(r'/b/(\d+)').firstMatch(href);
            if (idMatch == null) continue;
            final id = idMatch.group(1)!;
            final name = bookLink.text.trim();
            if (name.isEmpty) continue;
            final authorNames = <String>[];
            final authorIds = <String>[];
            for (final a in links.skip(1)) {
              final aHref = a.attributes['href'] ?? '';
              final aIdMatch = RegExp(r'/a/(\d+)').firstMatch(aHref);
              if (aIdMatch != null) {
                authorIds.add(aIdMatch.group(1)!);
                authorNames.add(a.text.trim());
              }
            }
            books.add(
              Book(
                id: id,
                title: name,
                authorIds: authorIds,
                authorNames: authorNames,
                genreIds: const [],
                description: null,
                coverUrl: null,
                publishDate: null,
                availableFormats: const [],
                source: BookSourceInfo(sourceId: 'flibusta', sourceUrl: '/b/$id'),
              ),
            );
          }
        }
      }

      final totalPages = _extractTotalPages(doc);

      return SearchResultPage(
        books: books,
        totalCount: books.length,
        currentPage: query.page,
        totalPages: totalPages,
        hasNextPage: query.page < totalPages - 1,
      );
    } on Object catch (e) {
      throw Exception('Failed to parse search results: $e');
    }
  }

  @override
  Future<SearchAuthorsResultPage> searchAuthors(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (query.hasFilters) {
      return const SearchAuthorsResultPage(authors: []);
    }
    final url = '/booksearch?ask=${Uri.encodeComponent(query.query)}&page=${query.page}&cha=on';
    final html = await _httpClient.getWithMirror(url, cancelToken: cancelToken);

    final doc = parse(html);
    final authors = <SearchAuthorResult>[];
    final main = doc.querySelector('#main');
    if (main != null) {
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
          final name = link.text.trim();
          if (name.isNotEmpty) {
            authors.add(SearchAuthorResult(id: idMatch.group(1)!, name: name));
          }
        }
      }
    }
    return SearchAuthorsResultPage(authors: authors);
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    try {
      final result = await _client.getBookDetails(bookId);
      final baseUrl = _client.dio.options.baseUrl;
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final book = Book(
        id: result.id,
        title: result.title,
        authorIds: result.authors,
        authorNames: result.authors,
        genreIds: result.genres,
        description: result.description.isNotEmpty ? result.description : null,
        coverUrl: result.coverUrl != null ? '$normalizedBase${result.coverUrl}' : null,
        publishDate: null,
        availableFormats: _parseFormats(result.formats),
        source: BookSourceInfo(
          sourceId: 'flibusta-api',
          sourceUrl: '$normalizedBase/b/$bookId',
        ),
      );

      return BookDetails(
        book: book,
        description: result.description.isNotEmpty ? result.description : null,
        availableFormats: _parseFormats(result.formats),
        downloadUrls: result.formats.map((f) => '$normalizedBase/b/$bookId/$f').toList(),
      );
    } on Object catch (e) {
      throw Exception('Failed to get book details: $e');
    }
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    final details = await getBookDetails(bookId);
    return details.availableFormats;
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    return _client.getDownloadUrl(bookId, format.name);
  }

  List<BookFormat> _parseFormats(List<String> formatStrings) {
    final formats = <BookFormat>[];
    for (final f in formatStrings) {
      final lower = f.toLowerCase();
      if (lower.contains('fb2')) {
        formats.add(BookFormat.fb2);
      } else if (lower.contains('epub')) {
        formats.add(BookFormat.epub);
      } else if (lower.contains('txt')) {
        formats.add(BookFormat.txt);
      } else if (lower.contains('pdf')) {
        formats.add(BookFormat.pdf);
      } else if (lower.contains('mobi')) {
        formats.add(BookFormat.mobi);
      } else if (lower.contains('rtf')) {
        formats.add(BookFormat.rtf);
      } else if (lower.contains('djvu') || lower.contains('djv')) {
        formats.add(BookFormat.djvu);
      }
    }
    return formats;
  }

  int _extractTotalPages(Document doc) {
    final pager = doc.querySelector('div.item-list .pager');
    if (pager == null) return 1;
    final items = pager.querySelectorAll('.pager-current, .pager-item');
    if (items.isEmpty) return 1;
    int maxPage = 1;
    for (final item in items) {
      final text = item.text.trim();
      final parsed = int.tryParse(text);
      if (parsed != null && parsed > maxPage) maxPage = parsed;
    }
    final hasNext = pager.querySelector('.pager-next') != null;
    return hasNext ? maxPage : maxPage;
  }
}

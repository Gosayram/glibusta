import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' show parse;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/http/http_client.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';

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
      coverUrl: coverUrl != null ? '$base$coverUrl' : null,
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
}

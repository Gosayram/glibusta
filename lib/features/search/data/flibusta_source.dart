import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' show parse;

import '../../../core/config/app_settings.dart';
import '../../../core/http/http_client.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';

final flibustaSourceProvider = Provider<FlibustaHtmlSource>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final client = HttpClient(
    baseUrl: settings.baseUrl,
    mirrors: settings.mirrors,
  );
  return FlibustaHtmlSource(client, settings.baseUrl);
});

class FlibustaHtmlSource extends BookSource {
  final HttpClient client;
  final String baseUrl;

  FlibustaHtmlSource(this.client, this.baseUrl);

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query) async {
    final searchUrl = _buildSearchUrl(query);
    final html = await client.getWithMirror(searchUrl);
    return _parseSearchResults(html, query);
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
    return '$baseUrl/b/$bookId/download/${format.name}';
  }

  String _buildSearchUrl(SearchQuery query) {
    final params = <String>[];
    if (query.query.isNotEmpty) {
      params.add('q=${Uri.encodeComponent(query.query)}');
    }
    if (query.author != null && query.author!.isNotEmpty) {
      params.add('author=${Uri.encodeComponent(query.author!)}');
    }
    if (query.title != null && query.title!.isNotEmpty) {
      params.add('title=${Uri.encodeComponent(query.title!)}');
    }
    if (query.series != null && query.series!.isNotEmpty) {
      params.add('series=${Uri.encodeComponent(query.series!)}');
    }
    if (query.genre != null && query.genre!.isNotEmpty) {
      params.add('genre=${Uri.encodeComponent(query.genre!)}');
    }
    if (query.page > 0) {
      params.add('page=${query.page + 1}');
    }
    return '/search?${params.join('&')}';
  }

  SearchResultPage _parseSearchResults(String html, SearchQuery query) {
    final document = parse(html);
    final books = <Book>[];

    final bookElements = document.querySelectorAll('table.series tr, div.book-item');
    for (final element in bookElements) {
      final book = _parseBookFromElement(element);
      if (book != null) {
        books.add(book);
      }
    }

    final pageInfo = _parsePagination(document);
    final hasNextPage = query.page < pageInfo.totalPages - 1;

    return SearchResultPage(
      books: books,
      totalCount: pageInfo.totalCount,
      currentPage: query.page,
      totalPages: pageInfo.totalPages,
      hasNextPage: hasNextPage,
    );
  }

  Book? _parseBookFromElement(Element element) {
    final id = _extractBookId(element);
    if (id == null) return null;

    final title = _extractTitle(element);
    if (title == null || title.isEmpty) return null;

    final authorNames = _extractAuthors(element);
    final authorIds = authorNames.map((a) => _slugify(a)).toList();

    final formats = _extractFormats(element);
    final coverUrl = _extractCoverUrl(element);
    final description = _extractDescription(element);

    return Book(
      id: id,
      title: title,
      authorIds: authorIds,
      genreIds: const [],
      description: description,
      coverUrl: coverUrl,
      publishDate: null,
      availableFormats: formats,
      source: BookSourceInfo(sourceId: 'flibusta', sourceUrl: '$baseUrl/b/$id'),
    );
  }

  BookDetails _parseBookDetails(String html, String bookId) {
    final document = parse(html);

    final title =
        document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim() ??
        '';

    final description = document
        .querySelector('.book_description, .description, #book_description')
        ?.text
        .trim();

    final authorElements = document.querySelectorAll('a[href^="/a/"], .book_author a');
    final authorIds = authorElements
        .map((a) => _extractIdFromHref(a.attributes['href'] ?? ''))
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final genreElements = document.querySelectorAll('a[href^="/g/"], .genre_list a');
    final genreIds = genreElements
        .map((g) => _extractIdFromHref(g.attributes['href'] ?? ''))
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final downloadElements = document.querySelectorAll(
      'a[href*="/download/"], a[href\$=".fb2"], a[href\$=".epub"], a[href\$=".txt"], a[href\$=".mobi"]',
    );
    final formats = <BookFormat>[];
    final downloadUrls = <String>[];

    for (final link in downloadElements) {
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      final format = _extractFormatFromHref(href);
      if (format != null && !formats.contains(format)) {
        formats.add(format);
      }
      if (!downloadUrls.contains(href)) {
        downloadUrls.add(href);
      }
    }

    final coverImg = document.querySelector(
      '.book_cover img, #book_cover img, img[src*="cover"]',
    );
    final coverUrl = coverImg?.attributes['src'];

    return BookDetails(
      book: Book(
        id: bookId,
        title: title,
        authorIds: authorIds,
        genreIds: genreIds,
        description: description,
        coverUrl: coverUrl,
        publishDate: null,
        availableFormats: formats,
        source: BookSourceInfo(
          sourceId: 'flibusta',
          sourceUrl: '$baseUrl/b/$bookId',
        ),
      ),
      description: description,
      availableFormats: formats,
      downloadUrls: downloadUrls,
    );
  }

  String? _extractBookId(Element element) {
    final links = element.querySelectorAll('a[href*="/b/"]');
    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final match = RegExp(r'/b/(\d+)').firstMatch(href);
      if (match != null) return match.group(1);
    }
    final anyLink = element.querySelector('a');
    if (anyLink != null) {
      final href = anyLink.attributes['href'] ?? '';
      final match = RegExp(r'/b/(\d+)').firstMatch(href);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _extractTitle(Element element) {
    final bookLink = element.querySelector('a[href*="/b/"]');
    if (bookLink != null && bookLink.text.trim().isNotEmpty) {
      return bookLink.text.trim();
    }
    return element.querySelector('a')?.text.trim();
  }

  List<String> _extractAuthors(Element element) {
    final authorLinks = element.querySelectorAll('a[href*="/a/"]');
    if (authorLinks.isEmpty) {
      final fallbackLinks = element.querySelectorAll('a.author, a.book-author, .author a');
      return fallbackLinks
          .map((Element a) => a.text.trim())
          .where((String t) => t.isNotEmpty)
          .toList();
    }
    return authorLinks.map((Element a) => a.text.trim()).where((String t) => t.isNotEmpty).toList();
  }

  List<BookFormat> _extractFormats(Element element) {
    final links = element.querySelectorAll(
      'a[href*="/download/"], a[href\$=".fb2"], a[href\$=".epub"], a[href\$=".txt"], a[href\$=".mobi"]',
    );
    final formats = <BookFormat>[];
    for (final Element link in links) {
      final href = link.attributes['href'] ?? '';
      final format = _extractFormatFromHref(href);
      if (format != null && !formats.contains(format)) {
        formats.add(format);
      }
    }
    return formats;
  }

  String? _extractCoverUrl(Element element) {
    final img = element.querySelector('img');
    return img?.attributes['src'];
  }

  String? _extractDescription(Element element) {
    final desc = element.querySelector('.annotation, .description, .book-description');
    return desc?.text.trim();
  }

  BookFormat? _extractFormatFromHref(String href) {
    final lower = href.toLowerCase();
    if (lower.endsWith('.fb2') || lower.contains('.fb2?')) return BookFormat.fb2;
    if (lower.endsWith('.epub') || lower.contains('.epub?')) {
      return BookFormat.epub;
    }
    if (lower.endsWith('.txt') || lower.contains('.txt?')) return BookFormat.txt;
    if (lower.endsWith('.mobi') || lower.contains('.mobi?')) {
      return BookFormat.mobi;
    }
    if (lower.endsWith('.pdf') || lower.contains('.pdf?')) return BookFormat.pdf;
    if (lower.endsWith('.djvu') || lower.contains('.djvu?')) {
      return BookFormat.djvu;
    }
    return null;
  }

  String? _extractIdFromHref(String href) {
    final match = RegExp(r'/[abg]/(\d+)').firstMatch(href);
    return match?.group(1);
  }

  _PaginationInfo _parsePagination(Document document) {
    final pageLinks = document.querySelectorAll('.pager a, .pagination a');
    var maxPage = 1;
    for (final Element link in pageLinks) {
      final text = link.text.trim();
      final pageNum = int.tryParse(text);
      if (pageNum != null && pageNum > maxPage) {
        maxPage = pageNum;
      }
    }

    final totalText = document.querySelector('.pager, .pagination')?.text ?? '';
    final totalMatch = RegExp(r'(\d+)').firstMatch(totalText);
    final totalCount = totalMatch != null ? int.tryParse(totalMatch.group(1) ?? '') ?? 0 : 0;

    return _PaginationInfo(totalCount: totalCount, totalPages: maxPage);
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

class _PaginationInfo {
  final int totalCount;
  final int totalPages;

  const _PaginationInfo({required this.totalCount, required this.totalPages});
}

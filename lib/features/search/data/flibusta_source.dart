import 'package:html/parser.dart' show parse;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../../shared/models/download_task.dart';
import '../domain/book_source.dart';
import '../../../core/http/http_client.dart';

final flibustaSourceProvider = Provider<FlibustaHtmlSource>((ref) {
  return FlibustaHtmlSource(HttpClient(baseUrl: 'https://flibusta.site'));
});

class FlibustaHtmlSource extends BookSource {
  final HttpClient client;

  FlibustaHtmlSource(this.client);

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query) async {
    final searchUrl = _buildSearchUrl(query);
    final response = await client.get(searchUrl);

    if (response == null) {
      return SearchResultPage(
        books: const [],
        totalCount: 0,
        currentPage: query.page,
        totalPages: 0,
        hasNextPage: false,
      );
    }

    return _parseSearchResults(response, query);
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    final response = await client.get('https://flibusta.site/b/$bookId');
    if (response == null) {
      return BookDetails(
        book: Book(
          id: bookId,
          title: '',
          authorIds: const [],
          genreIds: const [],
          description: null,
          coverUrl: null,
          publishDate: null,
          availableFormats: const [],
          source: BookSourceInfo(sourceId: 'flibusta', sourceUrl: ''),
        ),
        description: '',
        availableFormats: const [],
        downloadUrls: const [],
      );
    }

    return _parseBookDetails(response, bookId);
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    final details = await getBookDetails(bookId);
    return details.availableFormats;
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    return 'https://flibusta.site/b/$bookId/${format.name}';
  }

  String _buildSearchUrl(SearchQuery query) {
    final params = _buildQueryParams(query);
    return 'https://flibusta.site/search?${params.join('&')}';
  }

  List<String> _buildQueryParams(SearchQuery query) {
    final params = <String>[];
    if (query.query.isNotEmpty) params.add('q=${Uri.encodeComponent(query.query)}');
    if (query.author != null) params.add('author=${Uri.encodeComponent(query.author!)}');
    if (query.title != null) params.add('title=${Uri.encodeComponent(query.title!)}');
    if (query.page > 0) params.add('page=${query.page + 1}');
    return params;
  }

  SearchResultPage _parseSearchResults(String html, SearchQuery query) {
    final document = parse(html);
    final books = <Book>[];

    final bookElements = document.querySelectorAll('div.book-item, tr.series');
    for (final element in bookElements) {
      final id = _extractId(element);
      final title = _extractTitle(element);
      final authorLinks = element.querySelectorAll('a.author, a.book-author');

      if (id != null && title != null) {
        books.add(
          Book(
            id: id,
            title: title,
            authorIds: authorLinks.map((a) => a.text).toList(),
            genreIds: const [],
            description: null,
            coverUrl: null,
            publishDate: null,
            availableFormats: const [],
            source: BookSourceInfo(
              sourceId: 'flibusta',
              sourceUrl: 'https://flibusta.site',
            ),
          ),
        );
      }
    }

    return SearchResultPage(
      books: books,
      totalCount: books.length,
      currentPage: query.page,
      totalPages: (books.length / 20).ceil(),
      hasNextPage: false,
    );
  }

  BookDetails _parseBookDetails(String html, String bookId) {
    final document = parse(html);
    final title = document.querySelector('h1')?.text ?? '';
    final description = document.querySelector('.description, .book-description')?.text;
    final downloadLinks = document.querySelectorAll('a.dl, a.download');

    final formats = downloadLinks
        .map((a) => a.attributes['href'] ?? '')
        .map(_extractFormat)
        .whereType<BookFormat>()
        .toList();

    return BookDetails(
      book: Book(
        id: bookId,
        title: title,
        authorIds: const [],
        genreIds: const [],
        description: description,
        coverUrl: null,
        publishDate: null,
        availableFormats: formats,
        source: BookSourceInfo(
          sourceId: 'flibusta',
          sourceUrl: 'https://flibusta.site',
        ),
      ),
      description: description,
      availableFormats: formats,
      downloadUrls: downloadLinks.map((a) => a.attributes['href'] ?? '').toList(),
    );
  }

  String? _extractId(dynamic element) {
    final href = element.querySelector('a')?.attributes['href'];
    if (href != null) {
      final match = RegExp(r'/b/(\d+)').firstMatch(href);
      return match?.group(1);
    }
    return null;
  }

  String? _extractTitle(dynamic element) {
    return element.querySelector('a')?.text;
  }

  BookFormat? _extractFormat(String href) {
    if (href.contains('.fb2')) return BookFormat.fb2;
    if (href.contains('.epub')) return BookFormat.epub;
    if (href.contains('.txt')) return BookFormat.txt;
    return null;
  }
}
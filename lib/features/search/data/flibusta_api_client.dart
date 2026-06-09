import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_provider.dart';

final flibustaApiClientProvider = Provider<FlibustaApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return FlibustaApiClient(dio);
});

class FlibustaApiClient {
  final Dio _dio;

  FlibustaApiClient(this._dio);

  Dio get dio => _dio;

  Future<SearchByNameResponse> searchBooksByName(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'booksearch?ask=${Uri.encodeComponent(name)}&page=$page&chb=on';
    final response = await _dio.get<String>(url);
    return _parseSearchByNameResponse(response.data ?? '');
  }

  Future<SearchByNameResponse> searchBooksByNameOpds(
    String name, {
    int page = 0,
    int limit = 20,
  }) async {
    final url = 'opds/opensearch?searchTerm=${Uri.encodeComponent(name)}&searchType=books&pageNumber=$page';
    final response = await _dio.get<String>(url);
    return _parseOpdsSearchResponse(response.data ?? '');
  }

  Future<SearchAuthorsResponse> searchAuthors(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'authorsearch?ask=${Uri.encodeComponent(name)}&page=$page';
    final response = await _dio.get<String>(url);
    return _parseSearchAuthorsResponse(response.data ?? '');
  }

  Future<SearchSeriesResponse> searchBooksBySeries(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'series?search=${Uri.encodeComponent(name)}&page=$page';
    final response = await _dio.get<String>(url);
    return _parseSearchSeriesResponse(response.data ?? '');
  }

  Future<SearchGenresResponse> searchGenres(
    String name, {
    int page = 0,
    int limit = 50,
  }) async {
    final url = 'genres?search=${Uri.encodeComponent(name)}&page=$page';
    final response = await _dio.get<String>(url);
    return _parseSearchGenresResponse(response.data ?? '');
  }

  Future<BookDetailsResponse> getBookDetails(String bookId) async {
    final url = 'b/$bookId';
    final response = await _dio.get<String>(url);
    return _parseBookDetailsResponse(response.data ?? '', bookId);
  }

  Future<String> getDownloadUrl(String bookId, String format) async {
    return '${_dio.options.baseUrl}/b/$bookId/download/$format';
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
    final seriesRegex = RegExp(r'<li>.*?<a href="/s/(\d+)">(.*?)</a>.*?</li>', dotAll: true);
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

  BookDetailsResponse _parseBookDetailsResponse(String html, String bookId) {
    final titleMatch = RegExp(r'<h1>(.*?)</h1>').firstMatch(html);
    final title = titleMatch?.group(1) ?? '';

    final descriptionMatch = RegExp(r'<div class="book_description">(.*?)</div>', dotAll: true).firstMatch(html);
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

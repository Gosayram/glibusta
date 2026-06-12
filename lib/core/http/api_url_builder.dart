import 'package:shared_preferences/shared_preferences.dart';

class ApiUrlBuilder {
  ApiUrlBuilder({
    required this.host,
    this.scheme = 'https',
  });

  final String scheme;
  final String host;

  Uri bookSearch({
    required String query,
    int page = 0,
    String? filter,
  }) {
    return Uri(
      scheme: scheme,
      host: host,
      path: '/booksearch',
      queryParameters: {
        'ask': query.trim(),
        if (filter != null) filter: 'on',
        'page': page.toString(),
      },
    );
  }

  Uri bookSearchBooks({
    required String query,
    int page = 0,
  }) {
    return bookSearch(query: query, page: page, filter: 'chb');
  }

  Uri bookSearchAuthors({
    required String query,
    int page = 0,
  }) {
    return bookSearch(query: query, page: page, filter: 'cha');
  }

  Uri bookSearchSeries({
    required String query,
    int page = 0,
  }) {
    return bookSearch(query: query, page: page, filter: 'chs');
  }

  Uri bookSearchGenres({
    required String query,
    int page = 0,
  }) {
    return bookSearch(query: query, page: page, filter: 'chg');
  }

  Uri book(String id) {
    return Uri(scheme: scheme, host: host, path: '/b/$id');
  }

  Uri bookDownload(String id, String format) {
    return Uri(scheme: scheme, host: host, path: '/b/$id/$format');
  }

  Uri author(String id) {
    return Uri(scheme: scheme, host: host, path: '/a/$id');
  }

  Uri genre(String id) {
    return Uri(scheme: scheme, host: host, path: '/g/$id');
  }

  Uri genrePage(String id, {String order = 'a'}) {
    return Uri(
      scheme: scheme,
      host: host,
      path: '/g/$id',
      queryParameters: {'order': order},
    );
  }

  Uri series(String id) {
    return Uri(scheme: scheme, host: host, path: '/s/$id');
  }

  Uri popular() {
    return Uri(scheme: scheme, host: host, path: '/stat/b');
  }

  Uri recent({String? lang, String? type}) {
    return Uri(
      scheme: scheme,
      host: host,
      path: '/new',
      queryParameters: {
        if (lang != null) 'lang': lang,
        if (type != null) 'type': type,
      },
    );
  }

  Uri genres() {
    return Uri(scheme: scheme, host: host, path: '/g');
  }

  Uri cover(String bookId) {
    final idStr = bookId.toString();
    final y = idStr.length > 4 ? idStr.substring(4) : '0';
    return Uri(scheme: scheme, host: host, path: '/i/$y/$bookId/cover.jpg');
  }

  Uri opdsPopular() {
    return Uri(scheme: scheme, host: host, path: '/opds/popular');
  }

  Uri opdsRecent() {
    return Uri(scheme: scheme, host: host, path: '/opds/recent');
  }

  Uri opdsSearch({
    required String query,
    required String searchType,
    int page = 0,
  }) {
    return Uri(
      scheme: scheme,
      host: host,
      path: '/opds/opensearch',
      queryParameters: {
        'searchTerm': query.trim(),
        'searchType': searchType,
        'pageNumber': page.toString(),
      },
    );
  }

  static Future<ApiUrlBuilder> fromSettings() async {
    String baseUrl = 'https://www.flibusta.is';
    try {
      final env = await _loadBaseUrl();
      if (env != null) baseUrl = env;
    } on Object {}
    final uri = Uri.parse(baseUrl);
    return ApiUrlBuilder(host: uri.host, scheme: uri.scheme);
  }

  static Future<String?> _loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('base_url');
    } on Object {
      return null;
    }
  }
}

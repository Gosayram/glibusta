import 'package:dio/dio.dart';

/// MD-13.2: Calibre Content Server OPDS 1.0 client.
/// ponytail: basic catalog fetcher using Dio.
class CalibreClient {
  CalibreClient({required String baseUrl, Dio? dio}) : _dio = dio ?? Dio(), _baseUrl = baseUrl {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
  }

  final Dio _dio;
  final String _baseUrl;

  /// Check if Calibre server is reachable.
  Future<bool> ping() async {
    try {
      final response = await _dio.get<dynamic>('/opds');
      return response.statusCode == 200;
    } on Object {
      return false;
    }
  }

  /// Fetch the root OPDS catalog.
  Future<List<CalibreEntry>> fetchCatalog() async {
    final response = await _dio.get<dynamic>('/opds');
    return _parseOpds(response.data.toString());
  }

  /// Fetch books from a specific category.
  Future<List<CalibreEntry>> fetchCategory(String href) async {
    final response = await _dio.get<dynamic>(href);
    return _parseOpds(response.data.toString());
  }

  /// Download a book by its download URL.
  Future<List<int>> downloadBook(String href) async {
    final response = await _dio.get<List<int>>(
      href,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  /// ponytail: minimal OPDS Atom feed parser.
  List<CalibreEntry> _parseOpds(String xml) {
    final entries = <CalibreEntry>[];
    final entryPattern = RegExp(
      r'<entry>(.*?)</entry>',
      dotAll: true,
    );
    final titlePattern = RegExp(r'<title[^>]*>([^<]+)</title>');
    final idPattern = RegExp(r'<id>([^<]+)</id>');
    final linkPattern = RegExp(r'<link[^>]*href="([^"]+)"[^>]*/>');

    for (final entryMatch in entryPattern.allMatches(xml)) {
      final entryXml = entryMatch.group(1) ?? '';
      final title = titlePattern.firstMatch(entryXml)?.group(1) ?? '';
      final id = idPattern.firstMatch(entryXml)?.group(1) ?? '';
      final href = linkPattern.firstMatch(entryXml)?.group(1) ?? '';

      if (title.isNotEmpty) {
        entries.add(
          CalibreEntry(
            title: title,
            id: id,
            downloadHref: href,
          ),
        );
      }
    }
    return entries;
  }
}

class CalibreEntry {
  const CalibreEntry({
    required this.title,
    required this.id,
    this.downloadHref = '',
  });

  final String title;
  final String id;
  final String downloadHref;
}

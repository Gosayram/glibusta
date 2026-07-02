import 'package:dio/dio.dart';

/// MD-13.1: WebDAV client for cloud sync (progress, bookmarks, highlights).
/// ponytail: thin wrapper around Dio for WebDAV operations.
class WebDavClient {
  WebDavClient({required this.baseUrl, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.contentType = null;
  }

  final String baseUrl;
  final Dio _dio;

  Future<bool> ping() async {
    try {
      final response = await _dio.request<dynamic>(
        '/',
        options: Options(method: 'PROPFIND'),
      );
      return response.statusCode == 207 || response.statusCode == 200;
    } on Object {
      return false;
    }
  }

  Future<List<WebDavEntry>> list(String path) async {
    final response = await _dio.request<dynamic>(
      path,
      options: Options(method: 'PROPFIND', headers: {'Depth': '1'}),
    );
    return _parseMultiStatus(response.data.toString());
  }

  Future<void> upload(String path, List<int> data) async {
    await _dio.put<dynamic>(
      path,
      data: Stream.fromIterable([data]),
      options: Options(contentType: 'application/octet-stream'),
    );
  }

  Future<List<int>> download(String path) async {
    final response = await _dio.get<dynamic>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data as List<int>;
  }

  Future<void> delete(String path) async {
    await _dio.delete<dynamic>(path);
  }

  Future<void> mkdir(String path) async {
    await _dio.request<dynamic>(
      path,
      options: Options(method: 'MKCOL'),
    );
  }

  Future<bool> exists(String path) async {
    try {
      await _dio.request<dynamic>(
        path,
        options: Options(method: 'HEAD'),
      );
      return true;
    } on Object {
      return false;
    }
  }

  List<WebDavEntry> _parseMultiStatus(String body) {
    final entries = <WebDavEntry>[];
    final hrefPattern = RegExp(r'<d:href>([^<]+)</d:href>');
    for (final m in hrefPattern.allMatches(body)) {
      entries.add(WebDavEntry(path: m.group(1) ?? ''));
    }
    return entries;
  }
}

class WebDavEntry {
  const WebDavEntry({required this.path});
  final String path;
}

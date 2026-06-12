import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class RawHttpFallbackClient {
  RawHttpFallbackClient({String? userAgent}) : _userAgent = userAgent;

  final String? _userAgent;

  Future<String> get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = Duration.zero
      ..maxConnectionsPerHost = 1
      ..userAgent = _userAgent ??
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/131.0.6778.81 Mobile Safari/537.36';

    try {
      final request = await client.getUrl(uri);

      request.headers
        ..set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        ..set(HttpHeaders.acceptLanguageHeader, 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7')
        ..set(HttpHeaders.acceptEncodingHeader, 'identity')
        ..set(HttpHeaders.connectionHeader, 'close');

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      final bytes = await _consolidateResponse(response);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> getBytes(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = Duration.zero
      ..maxConnectionsPerHost = 1
      ..userAgent = _userAgent ??
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/131.0.6778.81 Mobile Safari/537.36';

    try {
      final request = await client.getUrl(uri);

      request.headers
        ..set(HttpHeaders.acceptHeader, '*/*')
        ..set(HttpHeaders.connectionHeader, 'close');

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      return await _consolidateResponse(response);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List> _consolidateResponse(
    HttpClientResponse response,
  ) async {
    final completer = Completer<Uint8List>();
    final bytes = <int>[];
    response.listen(
      bytes.addAll,
      onDone: () => completer.complete(Uint8List.fromList(bytes)),
      onError: completer.completeError,
    );
    return completer.future;
  }
}

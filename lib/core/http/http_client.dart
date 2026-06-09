import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_provider.dart';

final httpClientProvider = Provider<HttpClient>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpClient(dio);
});

class HttpClient {
  final Dio _dio;
  Map<String, String> _sessionCookies = {};

  HttpClient(this._dio);

  void setSessionCookies(Map<String, String> cookies) {
    _sessionCookies = Map.from(cookies);
    if (cookies.isNotEmpty) {
      final cookieHeader = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      _dio.options.headers['Cookie'] = cookieHeader;
    } else {
      _dio.options.headers.remove('Cookie');
    }
  }

  Map<String, String> get sessionCookies => Map.from(_sessionCookies);

  Dio get dio => _dio;

  Future<String> get(String url) async {
    try {
      final response = await _dio.get<String>(url);
      return response.data ?? '';
    } on DioException catch (e) {
      throw HttpException(
        message: e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
        url: url,
      );
    }
  }

  Future<String> getWithMirror(String path) async {
    final settings = _dio.options;
    final baseUrl = settings.baseUrl;
    final urls = [baseUrl].map((base) => '$base${path.startsWith('/') ? path : '/$path'}').toList();

    HttpException? lastError;
    for (final url in urls) {
      try {
        return await get(url);
      } on HttpException catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? const HttpException(message: 'No mirrors available');
  }

  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress != null
            ? (received, total) {
                onProgress(received, total > 0 ? total : 0);
              }
            : null,
      );
    } on DioException catch (e) {
      throw HttpException(
        message: e.message ?? 'Download failed',
        statusCode: e.response?.statusCode,
        url: url,
      );
    }
  }
}

class HttpException implements Exception {
  final String message;
  final int? statusCode;
  final String? url;

  const HttpException({
    required this.message,
    this.statusCode,
    this.url,
  });

  @override
  String toString() => 'HttpException($statusCode): $message [$url]';
}

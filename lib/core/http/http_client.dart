import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class _HttpOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
  }
}

class HttpClient {
  final String baseUrl;
  final List<String> mirrors;
  final Dio _dio;

  HttpClient({required this.baseUrl, this.mirrors = const []}) : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['User-Agent'] = 'Glibusta/0.1.0';
    _dio.options.responseType = ResponseType.plain;
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return io.HttpOverrides.current?.createHttpClient(null) ??
          io.HttpClient()
            ..badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
    };
  }

  static void enableSslBypass() {
    io.HttpOverrides.global = _HttpOverrides();
  }

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
    final urls = [
      baseUrl,
      ...mirrors,
    ].map((base) => '$base${path.startsWith('/') ? path : '/$path'}').toList();

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

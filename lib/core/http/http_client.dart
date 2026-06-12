import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_settings.dart';
import '../encoding/encoding_detection.dart';
import 'dio_provider.dart';

part 'http_client.g.dart';

@riverpod
HttpClient httpClient(Ref ref) {
  final dio = ref.watch(dioProvider);
  final settings = ref.watch(appSettingsControllerProvider);
  return HttpClient(dio, mirrors: [settings.baseUrl, ...settings.mirrors]);
}

class HttpClient {
  final Dio _dio;
  final List<String> _mirrors;
  final _encodingDetector = BookEncodingDetector();
  Map<String, String> _sessionCookies = {};

  HttpClient(this._dio, {List<String> mirrors = const []})
    : _mirrors = mirrors.isEmpty ? [_dio.options.baseUrl] : mirrors;

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

  Future<String> get(String url, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<Uint8List>(
        url,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return '';
      final result = await _encodingDetector.detect(bytes);
      return result.text;
    } on DioException catch (e) {
      throw _dioExceptionToHttpException(e, url);
    }
  }

  HttpException _dioExceptionToHttpException(DioException e, String url) {
    return HttpException(
      message: e.message ?? 'Request failed',
      statusCode: e.response?.statusCode,
      url: url,
    );
  }

  Future<String> getWithMirror(String path, {CancelToken? cancelToken}) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final seen = <String>{};
    final urls = <String>[];
    for (final raw in _mirrors) {
      final base = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
      final url = '$base$normalizedPath';
      if (seen.add(url)) urls.add(url);
    }

    HttpException? lastError;
    for (final url in urls) {
      try {
        return await get(url, cancelToken: cancelToken);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        lastError = _dioExceptionToHttpException(e, url);
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

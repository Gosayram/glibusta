import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_settings.dart';
import '../encoding/encoding_detection.dart';
import '../logging/app_logger.dart';
import '../theme/app_duration.dart';
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
  final _logger = AppLogger();
  Map<String, String> _sessionCookies = {};

  HttpClient(this._dio, {List<String> mirrors = const []})
    : _mirrors = mirrors.isEmpty ? [_dio.options.baseUrl] : mirrors;

  void setSessionCookies(Map<String, String> cookies) {
    _sessionCookies = Map.from(cookies);
  }

  Map<String, String> get sessionCookies => Map.from(_sessionCookies);

  Dio get dio => _dio;

  Future<String> getUri(Uri uri, {CancelToken? cancelToken}) async {
    final url = uri.toString();
    try {
      final response = await _dio.getUri<Uint8List>(
        uri,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return '';
      final result = await _encodingDetector.detect(bytes);
      return result.text;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw HttpException(message: 'Cancelled', url: url);
      }
      _logger.warning('Dio failed for $url: ${e.type}', name: 'Http');
      throw _dioExceptionToHttpException(e, url);
    }
  }

  Future<String> getUriWithFallback(Uri uri, {CancelToken? cancelToken}) async {
    try {
      return await getUri(uri, cancelToken: cancelToken);
    } on HttpException catch (e) {
      if (e.message == 'Cancelled') rethrow;
      return _rawGet(uri, cancelToken: cancelToken);
    }
  }

  /// Awaits an I/O operation while allowing Dio callers to cancel its fallback.
  ///
  /// Closing the native client in the caller's `finally` aborts the underlying
  /// socket after the cancellation future wins the race.
  Future<T> _awaitWithCancellation<T>(Future<T> operation, CancelToken? cancelToken) {
    if (cancelToken == null) return operation;
    return Future.any<T>([
      operation,
      cancelToken.whenCancel.then<T>(
        (_) => throw const HttpException(message: 'Cancelled'),
      ),
    ]);
  }

  /// Stops waiting for the next download chunk as soon as cancellation completes.
  ///
  /// `HttpClientResponse` is a stream, so checking cancellation only inside an
  /// `await for` body leaves a download blocked until the server sends another
  /// chunk. Racing each `moveNext` call makes cancellation prompt even for a
  /// stalled response. Errors from the cancellation notifier are intentionally
  /// ignored to preserve the previous best-effort cancellation contract.
  Future<T> _awaitDownloadOperation<T>(Future<T> operation, Future<void>? cancellation) {
    if (cancellation == null) return operation;
    return Future.any<T>([
      operation,
      cancellation.then<T>((_) => throw const HttpException(message: 'Cancelled')),
    ]);
  }

  Future<String> _rawGet(Uri uri, {CancelToken? cancelToken}) async {
    final client = io.HttpClient()
      ..connectionTimeout = AppDuration.httpConnect
      ..idleTimeout = AppDuration.httpIdle
      ..maxConnectionsPerHost = 1;

    try {
      final request = await _awaitWithCancellation(client.getUrl(uri), cancelToken);
      request.headers
        ..set(
          io.HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        )
        ..set(io.HttpHeaders.acceptLanguageHeader, 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7')
        ..set(io.HttpHeaders.acceptEncodingHeader, 'gzip, deflate')
        ..set(io.HttpHeaders.connectionHeader, 'close');

      final ua = await _getOrCreateUserAgent();
      if (ua != null) {
        request.headers.set(io.HttpHeaders.userAgentHeader, ua);
      }

      final response = await _awaitWithCancellation(
        request.close().timeout(AppDuration.httpReceive),
        cancelToken,
      );

      final completer = Completer<Uint8List>();
      final bytes = <int>[];
      response.listen(
        bytes.addAll,
        onDone: () => completer.complete(Uint8List.fromList(bytes)),
        onError: completer.completeError,
      );
      final rawBytes = await _awaitWithCancellation(completer.future, cancelToken);

      if (rawBytes.isEmpty) return '';
      final detected = await _encodingDetector.detect(rawBytes);
      return detected.text;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _getOrCreateUserAgent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('device_user_agent');
    } on Object {
      return null;
    }
  }

  Future<String> get(String url, {CancelToken? cancelToken}) async {
    final uri = Uri.parse(url);
    return getUri(uri, cancelToken: cancelToken);
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
        final uri = Uri.parse(url);
        return await getUriWithFallback(uri, cancelToken: cancelToken);
      } on HttpException catch (e) {
        if (e.message == 'Cancelled') rethrow;
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
    Future<void>? onCancel,
    int startBytes = 0,
  }) async {
    final uri = Uri.parse(url);
    final client = io.HttpClient()
      ..connectionTimeout = AppDuration.httpConnect
      ..idleTimeout = AppDuration.httpDownloadIdle
      ..maxConnectionsPerHost = 1;
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(io.HttpHeaders.acceptHeader, '*/*')
        ..set(io.HttpHeaders.connectionHeader, 'close');

      if (startBytes > 0) {
        request.headers.set(io.HttpHeaders.rangeHeader, 'bytes=$startBytes-');
      }

      if (_sessionCookies.isNotEmpty) {
        final cookieHeader = _sessionCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
        request.headers.set(io.HttpHeaders.cookieHeader, cookieHeader);
      }

      final ua = await _getOrCreateUserAgent();
      if (ua != null) {
        request.headers.set(io.HttpHeaders.userAgentHeader, ua);
      }

      final response = await request.close().timeout(
        AppDuration.httpDownloadResponse,
      );

      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException(
          message: 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          url: url,
        );
      }

      final file = io.File(savePath);
      final sink = file.openWrite(mode: startBytes > 0 ? io.FileMode.append : io.FileMode.write);
      final cancellation = onCancel?.catchError((Object _) {});
      try {
        int received = 0;
        final total = response.contentLength;

        final iterator = StreamIterator<List<int>>(response);
        try {
          while (await _awaitDownloadOperation(iterator.moveNext(), cancellation)) {
            final chunk = iterator.current;
            sink.add(chunk);
            received += chunk.length;
            if (onProgress != null) {
              onProgress(received, total);
            }
          }
        } finally {
          await iterator.cancel();
        }
        await sink.close();

        if (received == 0) {
          throw HttpException(message: 'Empty download', url: url);
        }

        final contentType = response.headers.value(io.HttpHeaders.contentTypeHeader) ?? '';
        if (contentType.contains('text/html') || contentType.contains('text/plain')) {
          final bytes = await file.readAsBytes();
          final result = await _encodingDetector.detect(bytes);
          if (result.text.contains('Книга не найдена') || result.text.contains('<html')) {
            await file.delete();
            throw HttpException(message: 'Server returned HTML instead of book file', url: url);
          }
        }
      } on Object catch (_) {
        await sink.close().catchError((_) {});
        try {
          if (await file.exists()) await file.delete();
        } on Object {
          // Best-effort: ignore file deletion errors
        }
        rethrow;
      }
    } finally {
      client.close(force: true);
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

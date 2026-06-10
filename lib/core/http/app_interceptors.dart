import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../auth/auth_repository.dart';

final _log = Logger('AppInterceptors');

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final authState = _ref.read(authStateProvider);
    final session = authState.value?.session;
    if (session != null && session.cookies.isNotEmpty) {
      final cookieHeader = session.cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      options.headers['Cookie'] = cookieHeader;
    }
    handler.next(options);
  }
}

class LoggingInterceptor extends Interceptor {
  static Uri _redactedUri(Uri uri) => uri.replace(query: '');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log.info('→ ${options.method} ${_redactedUri(options.uri)}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log.info('← ${response.statusCode} ${_redactedUri(response.requestOptions.uri)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.severe(
      '✗ ${err.requestOptions.method} ${_redactedUri(err.requestOptions.uri)} '
      '${err.response?.statusCode} ${err.message}',
    );
    handler.next(err);
  }
}

class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mappedError = _mapError(err);
    handler.next(mappedError);
  }

  DioException _mapError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return DioException(
          requestOptions: err.requestOptions,
          error: 'Network timeout. Check your connection.',
          type: err.type,
        );
      case DioExceptionType.connectionError:
        return DioException(
          requestOptions: err.requestOptions,
          error: 'No internet connection.',
          type: err.type,
        );
      case DioExceptionType.badResponse:
        return _mapStatusCode(err);
      default:
        return err;
    }
  }

  DioException _mapStatusCode(DioException err) {
    final statusCode = err.response?.statusCode;
    switch (statusCode) {
      case 401:
        return DioException(
          requestOptions: err.requestOptions,
          error: 'Unauthorized. Please log in again.',
          type: err.type,
          response: err.response,
        );
      case 403:
        return DioException(
          requestOptions: err.requestOptions,
          error: 'Access denied.',
          type: err.type,
          response: err.response,
        );
      case 404:
        return DioException(
          requestOptions: err.requestOptions,
          error: 'Resource not found.',
          type: err.type,
          response: err.response,
        );
      case 500:
        return DioException(
          requestOptions: err.requestOptions,
          error: 'Server error. Please try again later.',
          type: err.type,
          response: err.response,
        );
      default:
        return err;
    }
  }
}

import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_settings.dart';
import '../theme/app_duration.dart';
import 'app_interceptors.dart';

part 'dio_provider.g.dart';

class _HttpOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
  }
}

void enableSslBypass() {
  io.HttpOverrides.global = _HttpOverrides();
}

@riverpod
Dio dio(Ref ref) {
  final settings = ref.watch(appSettingsControllerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: settings.baseUrl,
      connectTimeout: AppDuration.httpConnect,
      receiveTimeout: AppDuration.httpReceive,
      headers: {
        'User-Agent': 'Glibusta/0.1.0',
      },
      responseType: ResponseType.plain,
    ),
  );
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    return io.HttpClient()
      ..badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
  };
  dio.interceptors.addAll([
    AuthInterceptor(ref),
    LoggingInterceptor(),
    ErrorMappingInterceptor(),
    _RetryInterceptor(dio: dio, maxRetries: 3),
  ]);
  return dio;
}

class _RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Dio _dio;

  _RetryInterceptor({required this.maxRetries, required Dio dio}) : _dio = dio;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldNotRetry(err)) {
      handler.next(err);
      return;
    }

    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    if (retryCount >= maxRetries) {
      handler.next(err);
      return;
    }

    final delay = Duration(seconds: 1 << retryCount);
    await Future<void>.delayed(delay);

    final options = Options(
      method: err.requestOptions.method,
      headers: err.requestOptions.headers,
      extra: {...err.requestOptions.extra, 'retryCount': retryCount + 1},
    );

    try {
      final response = await _dio.request<dynamic>(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: options,
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldNotRetry(DioException err) {
    if (err.type == DioExceptionType.cancel) return true;
    final status = err.response?.statusCode;
    if (status == 401 || status == 403 || status == 404) return true;
    return false;
  }
}

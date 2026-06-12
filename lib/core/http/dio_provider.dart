import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_settings.dart';
import '../logging/app_logger.dart';
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
    LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      logPrint: (obj) => AppLogger().finest('$obj', name: 'Http'),
    ),
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
  final _logger = AppLogger();

  _RetryInterceptor({required this.maxRetries, required Dio dio}) : _dio = dio;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldNotRetry(err)) {
      _logger.info('Skipping retry: ${err.type}', name: 'Http');
      handler.next(err);
      return;
    }

    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    if (retryCount >= maxRetries) {
      _logger.warning(
        'Max retries ($maxRetries) exhausted for ${err.requestOptions.path}',
        name: 'Http',
      );
      handler.next(err);
      return;
    }

    _logger.info(
      'Retrying ${err.requestOptions.path} (attempt ${retryCount + 1}/$maxRetries)',
      name: 'Http',
    );

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
      _logger.info(
        'Retry succeeded for ${err.requestOptions.path}',
        name: 'Http',
      );
      handler.resolve(response);
    } on DioException catch (e) {
      _logger.warning(
        'Retry failed for ${err.requestOptions.path}: ${e.type}',
        name: 'Http',
      );
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

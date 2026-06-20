import 'dart:math';

import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/auth_repository.dart';
import '../config/app_settings.dart';
import '../logging/app_logger.dart';
import '../theme/app_duration.dart';
import 'app_interceptors.dart';
import 'user_agent.dart';

part 'dio_provider.g.dart';

@riverpod
Dio dio(Ref ref) {
  final settings = ref.watch(appSettingsControllerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: settings.baseUrl,
      connectTimeout: AppDuration.httpConnect,
      receiveTimeout: AppDuration.httpReceive,
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
      followRedirects: true,
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Connection': 'close',
      },
    ),
  );

  dio.httpClientAdapter = NativeAdapter();

  dio.interceptors.addAll([
    const _UserAgentInterceptor(),
    AuthInterceptor(ref),
    SessionRefreshInterceptor(ref),
    LoggingInterceptor(),
    ErrorMappingInterceptor(),
    _RetryInterceptor(dio: dio, maxRetries: 3),
  ]);
  return dio;
}

class _UserAgentInterceptor extends Interceptor {
  const _UserAgentInterceptor();

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    String ua;
    try {
      ua = await DeviceUserAgent.get();
    } on Object {
      ua =
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/131.0.6778.81 Mobile Safari/537.36';
    }
    options.headers['User-Agent'] = ua;
    options.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    options.headers['Accept-Language'] = 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7';
    options.headers['Accept-Encoding'] = 'gzip, deflate, br';
    options.headers['Sec-Fetch-Dest'] = 'document';
    options.headers['Sec-Fetch-Mode'] = 'navigate';
    options.headers['Sec-Fetch-Site'] = 'none';
    options.headers['Sec-Fetch-User'] = '?1';
    options.headers['Sec-CH-UA-Mobile'] = '?1';
    options.headers['Sec-CH-UA-Platform'] = '"Android"';
    handler.next(options);
  }
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

    final delay = Duration(
      milliseconds: (1 << retryCount) * 1000 + Random().nextInt(1000),
    );
    await Future<void>.delayed(delay);

    final options = Options(
      method: err.requestOptions.method,
      headers: err.requestOptions.headers,
      extra: {...err.requestOptions.extra, 'retryCount': retryCount + 1},
    );

    try {
      final requestOptions = err.requestOptions;
      final uri = requestOptions.uri;
      final response = await _dio.request<dynamic>(
        uri.toString(),
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
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
    final method = err.requestOptions.method.toUpperCase();
    final isSafeRetryMethod = method == 'GET' || method == 'HEAD' || method == 'OPTIONS';
    final retryOptIn = err.requestOptions.extra['retryable'] == true;
    if (!isSafeRetryMethod && !retryOptIn) return true;
    final status = err.response?.statusCode;
    if (status == 400 || status == 401 || status == 403 || status == 404 || status == 422) {
      return true;
    }
    return false;
  }
}

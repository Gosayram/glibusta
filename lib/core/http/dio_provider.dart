import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_settings.dart';

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

final dioProvider = Provider<Dio>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final dio = Dio(BaseOptions(
    baseUrl: settings.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Glibusta/0.1.0',
    },
    responseType: ResponseType.plain,
  ));
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    return io.HttpClient()
      ..badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
  };
  return dio;
});

import 'package:dio/dio.dart';

class HttpClient {
  final String baseUrl;
  final List<String> mirrors;
  final Dio _dio;

  HttpClient({required this.baseUrl, this.mirrors = const []}) : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['User-Agent'] = 'Glibusta/0.1.0';
  }

  Future<String?> get(String url) async {
    try {
      final response = await _dio.get(url);
      return response.data?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<void> download(String url, String savePath) async {
    await _dio.download(url, savePath);
  }
}
class HttpClient {
  final String baseUrl;
  final List<String> mirrors;

  HttpClient({required this.baseUrl, this.mirrors = const []});
}
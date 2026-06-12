import 'package:dio/dio.dart';

class CancelTokenManager {
  CancelTokenManager._();

  static final Map<String, CancelToken> _tokens = {};

  static CancelToken create(String key) {
    _tokens[key]?.cancel();
    final token = CancelToken();
    _tokens[key] = token;
    return token;
  }

  static void cancel(String key) {
    _tokens[key]?.cancel();
    _tokens.remove(key);
  }

  static void cancelAll() {
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
  }

  static bool isCancelled(String key) {
    return _tokens[key]?.isCancelled ?? true;
  }
}

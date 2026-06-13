import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/http/http_client.dart';

void main() {
  group('HttpException', () {
    test('toString includes statusCode, message, url', () {
      const e = HttpException(
        message: 'Not Found',
        statusCode: 404,
        url: 'https://example.com/book/1',
      );
      final str = e.toString();
      expect(str, contains('404'));
      expect(str, contains('Not Found'));
      expect(str, contains('https://example.com/book/1'));
    });

    test('statusCode and url are nullable', () {
      const e = HttpException(message: 'error');
      expect(e.statusCode, isNull);
      expect(e.url, isNull);
    });

    test('message is required', () {
      const e = HttpException(message: 'test');
      expect(e.message, 'test');
    });
  });
}

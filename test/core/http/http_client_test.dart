import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
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

  group('HttpClient.download', () {
    test('cancels while the response is waiting for its next chunk', () async {
      await io.HttpOverrides.runZoned(
        () async {
          final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
          final firstChunkSent = Completer<void>();
          final finishResponse = Completer<void>();
          final cancellation = Completer<void>();
          final tempDirectory = await io.Directory.systemTemp.createTemp(
            'glibusta_http_client_test',
          );
          final file = io.File('${tempDirectory.path}/book.fb2');

          final subscription = server.listen((request) async {
            try {
              request.response.contentLength = 2;
              request.response.add([0]);
              await request.response.flush();
              firstChunkSent.complete();
              await finishResponse.future;
              request.response.add([1]);
              await request.response.close();
            } on io.HttpException {
              // The client closes its socket immediately after cancellation.
            }
          });
          addTearDown(() async {
            if (!finishResponse.isCompleted) finishResponse.complete();
            await subscription.cancel();
            await server.close(force: true);
            await tempDirectory.delete(recursive: true);
          });

          final download = HttpClient(Dio()).download(
            'http://${server.address.host}:${server.port}/book.fb2',
            file.path,
            onCancel: cancellation.future,
          );

          await firstChunkSent.future;
          cancellation.complete();

          await expectLater(
            download,
            throwsA(
              isA<HttpException>().having((error) => error.message, 'message', 'Cancelled'),
            ),
          );
          expect(file.exists(), completion(isFalse));
        },
        createHttpClient: (context) => _RealHttpClientFactory().create(context),
      );
    });
  });
}

class _RealHttpClientFactory extends io.HttpOverrides {
  io.HttpClient create(io.SecurityContext? context) => super.createHttpClient(context);
}

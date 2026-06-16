import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/errors/failures.dart';

void main() {
  group('AppFailure subclasses', () {
    test('NetworkFailure with message', () {
      const f = NetworkFailure('timeout');
      expect(f.message, 'timeout');
      expect(f.toString(), contains('NetworkFailure'));
      expect(f.toString(), contains('timeout'));
    });

    test('NetworkFailure without message', () {
      const f = NetworkFailure();
      expect(f.message, isNull);
      expect(f.toString(), contains('Unknown error'));
    });

    test('NotFoundFailure with message', () {
      const f = NotFoundFailure('not here');
      expect(f.message, 'not here');
      expect(f.toString(), contains('NotFoundFailure'));
    });

    test('BookMissingFailure with message', () {
      const f = BookMissingFailure('not found');
      expect(f.message, 'not found');
      expect(f.toString(), contains('BookMissingFailure'));
      expect(f, isA<BookOpenFailure>());
    });

    test('UnsupportedFormatFailure with message', () {
      const f = UnsupportedFormatFailure('pdf');
      expect(f.message, 'pdf');
      expect(f.toString(), contains('UnsupportedFormatFailure'));
      expect(f, isA<BookOpenFailure>());
    });

    test('ParserTimeoutFailure with message', () {
      const f = ParserTimeoutFailure('slow');
      expect(f.message, 'slow');
      expect(f, isA<BookOpenFailure>());
    });

    test('CacheCorruptedFailure with message', () {
      const f = CacheCorruptedFailure('bad json');
      expect(f.message, 'bad json');
      expect(f, isA<BookOpenFailure>());
    });

    test('InvalidEncodingFailure with message', () {
      const f = InvalidEncodingFailure('bad charset');
      expect(f.message, 'bad charset');
      expect(f, isA<BookOpenFailure>());
    });

    test('UnknownBookOpenFailure', () {
      const f = UnknownBookOpenFailure();
      expect(f, isA<BookOpenFailure>());
      expect(f, isA<AppFailure>());
    });

    test('SourceUnavailableFailure with message', () {
      const f = SourceUnavailableFailure('server down');
      expect(f.message, 'server down');
      expect(f.toString(), contains('SourceUnavailableFailure'));
    });

    test('ParserFailure with message', () {
      const f = ParserFailure('bad xml');
      expect(f.message, 'bad xml');
      expect(f.toString(), contains('ParserFailure'));
    });

    test('DownloadFailure with message', () {
      const f = DownloadFailure('404');
      expect(f.message, '404');
      expect(f.toString(), contains('DownloadFailure'));
    });

    test('StorageFailure with message', () {
      const f = StorageFailure('disk full');
      expect(f.message, 'disk full');
      expect(f.toString(), contains('StorageFailure'));
    });

    test('AuthFailure with message', () {
      const f = AuthFailure('wrong password');
      expect(f.message, 'wrong password');
      expect(f.toString(), contains('AuthFailure'));
    });

    test('CancelledFailure has no message', () {
      const f = CancelledFailure();
      expect(f.message, isNull);
      expect(f.toString(), contains('CancelledFailure'));
    });

    test('UnknownFailure with message and stackTrace', () {
      final st = StackTrace.current;
      final f = UnknownFailure('weird', st);
      expect(f.message, 'weird');
      expect(f.stackTrace, st);
      expect(f.toString(), contains('UnknownFailure'));
    });

    test('UnknownFailure without message', () {
      const f = UnknownFailure();
      expect(f.message, isNull);
      expect(f.stackTrace, isNull);
    });
  });
}

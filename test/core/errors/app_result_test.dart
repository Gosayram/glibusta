import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/errors/app_result.dart';
import 'package:glibusta/core/errors/failures.dart';

void main() {
  group('Success', () {
    test('isSuccess is true', () {
      const result = Success(42);
      expect(result.isSuccess, isTrue);
    });

    test('isFailure is false', () {
      const result = Success('hello');
      expect(result.isFailure, isFalse);
    });

    test('value returns the wrapped value', () {
      const result = Success<int>(7);
      expect(result.value, 7);
    });

    test('failure is null', () {
      const result = Success(1);
      expect(result.failure, isNull);
    });
  });

  group('Failure', () {
    test('isSuccess is false', () {
      const result = Failure<int>(NetworkFailure('no net'));
      expect(result.isSuccess, isFalse);
    });

    test('isFailure is true', () {
      const result = Failure<int>(NetworkFailure());
      expect(result.isFailure, isTrue);
    });

    test('value is null', () {
      const result = Failure<String>(NotFoundFailure());
      expect(result.value, isNull);
    });

    test('failure returns the AppFailure', () {
      const f = ParserFailure('bad xml');
      const result = Failure<int>(f);
      expect(result.failure, same(f));
    });
  });

  group('AppResult.map', () {
    test('transforms Success value', () {
      const result = Success(10);
      final mapped = result.map((v) => v * 2);
      expect(mapped.isSuccess, isTrue);
      expect(mapped.value, 20);
    });

    test('propagates Failure without transforming', () {
      const result = Failure<int>(NetworkFailure('err'));
      final mapped = result.map((v) => v * 2);
      expect(mapped.isFailure, isTrue);
      expect(mapped.failure, isA<NetworkFailure>());
    });
  });

  group('AppResult.flatMap', () {
    test('chains Success into new Result', () {
      const result = Success(5);
      final flat = result.flatMap((v) => Success(v + 1));
      expect(flat.value, 6);
    });

    test('chains Failure into new Result', () {
      const result = Failure<int>(NotFoundFailure());
      final flat = result.flatMap((v) => Success(v + 1));
      expect(flat.isFailure, isTrue);
    });

    test('can return Failure from transform', () {
      const result = Success(0);
      final flat = result.flatMap((v) => const Failure<String>(ParserFailure('zero')));
      expect(flat.isFailure, isTrue);
      expect(flat.failure, isA<ParserFailure>());
    });
  });

  group('guardFuture', () {
    test('returns Success on successful future', () async {
      final result = await guardFuture(() async => 42);
      expect(result.isSuccess, isTrue);
      expect(result.value, 42);
    });

    test('returns Failure on AppFailure', () async {
      final result = await guardFuture<int>(
        () async => throw const NetworkFailure('timeout'),
      );
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });

    test('returns Failure on generic exception', () async {
      final result = await guardFuture<int>(
        () async => throw Exception('unexpected'),
      );
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<UnknownFailure>());
    });
  });
}

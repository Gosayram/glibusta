
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/utils/fire_and_log.dart';

void main() {
  group('fireAndLog', () {
    test('completes silently on success', () async {
      var called = false;
      fireAndLog(() async {
        called = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(called, isTrue);
    });

    test('catches and does not throw on error', () async {
      var errorThrown = false;
      try {
        fireAndLog(() async {
          throw StateError('boom');
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } on Object {
        errorThrown = true;
      }
      expect(errorThrown, isFalse);
    });

    test('accepts name and context parameters', () async {
      fireAndLog(
        () async => throw StateError('test'),
        name: 'TestOp',
        context: 'unit test',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}

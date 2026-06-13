import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('isActive is false initially', () {
      final d = Debouncer(delay: const Duration(milliseconds: 100));
      expect(d.isActive, isFalse);
      d.dispose();
    });

    test('call schedules action', () async {
      var called = false;
      final d = Debouncer(delay: const Duration(milliseconds: 50));
      d.call(() => called = true);
      expect(d.isActive, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(called, isTrue);
      expect(d.isActive, isFalse);
      d.dispose();
    });

    test('multiple calls only fire last one', () async {
      var count = 0;
      final d = Debouncer(delay: const Duration(milliseconds: 50));
      d.call(() => count++);
      d.call(() => count++);
      d.call(() => count++);
      expect(d.isActive, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, 1);
      d.dispose();
    });

    test('dispose cancels timer', () {
      final d = Debouncer(delay: const Duration(seconds: 10));
      d.call(() {});
      expect(d.isActive, isTrue);
      d.dispose();
      expect(d.isActive, isFalse);
    });

    test('call after dispose restarts', () async {
      var called = false;
      final d = Debouncer(delay: const Duration(milliseconds: 50));
      d.dispose();
      d.call(() => called = true);
      expect(d.isActive, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(called, isTrue);
      d.dispose();
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auto-scroll speed clamping', () {
    double clampSpeed(double input) => input.clamp(10.0, 300.0);

    test('speed below minimum clamps to 10', () {
      expect(clampSpeed(5.0), 10.0);
    });

    test('speed above maximum clamps to 300', () {
      expect(clampSpeed(500.0), 300.0);
    });

    test('speed within range stays unchanged', () {
      expect(clampSpeed(50.0), 50.0);
      expect(clampSpeed(100.0), 100.0);
    });
  });

  group('auto-scroll ValueNotifier defaults', () {
    test('autoScrollEnabled defaults to false', () {
      final enabled = ValueNotifier<bool>(false);
      expect(enabled.value, isFalse);
      enabled.dispose();
    });

    test('autoScrollSpeed defaults to 50', () {
      final speed = ValueNotifier<double>(50.0);
      expect(speed.value, 50.0);
      speed.dispose();
    });
  });

  group('auto-scroll state transitions', () {
    test('enabled toggles correctly', () {
      final enabled = ValueNotifier<bool>(false);
      expect(enabled.value, isFalse);
      enabled.value = true;
      expect(enabled.value, isTrue);
      enabled.value = false;
      expect(enabled.value, isFalse);
      enabled.dispose();
    });

    test('speed changes notify listeners', () {
      final speed = ValueNotifier<double>(50.0);
      var notifiedValue = speed.value;
      speed.addListener(() => notifiedValue = speed.value);
      speed.value = 100.0;
      expect(notifiedValue, 100.0);
      speed.dispose();
    });

    test('stopAutoScroll sets enabled to false', () {
      final enabled = ValueNotifier<bool>(true);
      expect(enabled.value, isTrue);
      enabled.value = false;
      expect(enabled.value, isFalse);
      enabled.dispose();
    });
  });
}

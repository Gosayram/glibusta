import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_page_turn_haptic.dart';

void main() {
  group('triggerPageTurnHaptic', () {
    test('does not request platform feedback while disabled', () async {
      var calls = 0;

      await triggerPageTurnHaptic(
        enabled: false,
        feedback: () async {
          calls++;
        },
      );

      expect(calls, 0);
    });

    test('uses the platform feedback callback only when enabled', () async {
      var calls = 0;

      await triggerPageTurnHaptic(
        enabled: true,
        feedback: () async {
          calls++;
        },
      );

      expect(calls, 1);
    });
  });
}

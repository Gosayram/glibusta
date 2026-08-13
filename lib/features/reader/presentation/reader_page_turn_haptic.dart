import 'package:flutter/services.dart';

typedef PageTurnHapticCallback = Future<void> Function();

/// Requests a platform-native haptic tick for a completed page turn.
///
/// Flutter delegates this to the platform: devices without a haptic actuator,
/// and system configurations that suppress haptics, perform no feedback. The
/// reader never simulates a vibration itself.
Future<void> triggerPageTurnHaptic({
  required bool enabled,
  PageTurnHapticCallback feedback = HapticFeedback.selectionClick,
}) async {
  if (!enabled) return;
  await feedback();
}

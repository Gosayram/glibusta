import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PlatformService {
  PlatformService() : _battery = Battery();

  final Battery _battery;
  bool _wakelockEnabled = false;

  bool get isWakelockEnabled => _wakelockEnabled;

  Future<void> enableWakelock() async {
    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
  }

  Future<void> disableWakelock() async {
    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }
  }

  Future<void> toggleWakelock() async {
    if (_wakelockEnabled) {
      await disableWakelock();
    } else {
      await enableWakelock();
    }
  }

  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      debugPrint('Failed to get battery level: $e');
      return -1;
    }
  }

  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;

  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (e) {
      debugPrint('Failed to check charging state: $e');
      return false;
    }
  }

  void dispose() {
    if (_wakelockEnabled) {
      WakelockPlus.disable();
    }
  }
}

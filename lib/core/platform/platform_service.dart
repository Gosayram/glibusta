import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logging/app_logger.dart';

class PlatformService {
  PlatformService() : _battery = Battery();

  final Battery _battery;
  final _logger = AppLogger();
  bool _wakelockEnabled = false;

  bool get isWakelockEnabled => _wakelockEnabled;

  Future<void> enableWakelock() async {
    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
    } on Object catch (e) {
      _logger.warning('Failed to enable wakelock: $e', name: 'Platform');
    }
  }

  Future<void> disableWakelock() async {
    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
    } on Object catch (e) {
      _logger.warning('Failed to disable wakelock: $e', name: 'Platform');
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
    } on Object catch (e) {
      _logger.warning('Failed to get battery level: $e', name: 'Platform');
      return -1;
    }
  }

  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;

  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } on Object catch (e) {
      _logger.warning('Failed to check charging state: $e', name: 'Platform');
      return false;
    }
  }

  void dispose() {
    if (_wakelockEnabled) {
      unawaited(WakelockPlus.disable());
    }
  }
}

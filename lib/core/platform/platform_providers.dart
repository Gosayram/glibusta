import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_service.dart';

final platformServiceProvider = Provider<PlatformService>((ref) {
  final service = PlatformService();
  ref.onDispose(service.dispose);
  return service;
});

final batteryLevelProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(platformServiceProvider);
  return service.getBatteryLevel();
});

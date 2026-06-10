import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_capabilities.dart';

final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  return const LivePlatformCapabilities();
});

extension PlatformCapabilitiesRef on WidgetRef {
  PlatformCapabilities get platformCapabilities => read(platformCapabilitiesProvider);
}

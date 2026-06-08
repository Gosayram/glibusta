import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_capabilities.dart';

final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  return const PlatformCapabilities(
    hasArbitraryFileSelection: false,
    supportsBackgroundDownloads: false,
    supportsSystemNotifications: false,
    hasNativeMenuBar: false,
    supportsFileAssociations: false,
    canOpenFileExternally: true,
    needsStoragePermission: true,
  );
});

extension PlatformCapabilitiesRef on WidgetRef {
  PlatformCapabilities get platformCapabilities => read(platformCapabilitiesProvider);
}
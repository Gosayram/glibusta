class PlatformCapabilities {
  final bool hasArbitraryFileSelection;
  final bool supportsBackgroundDownloads;
  final bool supportsSystemNotifications;
  final bool hasNativeMenuBar;
  final bool supportsFileAssociations;
  final bool canOpenFileExternally;
  final bool needsStoragePermission;

  const PlatformCapabilities({
    required this.hasArbitraryFileSelection,
    required this.supportsBackgroundDownloads,
    required this.supportsSystemNotifications,
    required this.hasNativeMenuBar,
    required this.supportsFileAssociations,
    required this.canOpenFileExternally,
    required this.needsStoragePermission,
  });
}

abstract class PlatformService {
  PlatformCapabilities getCapabilities();
  Future<void> openFile(String path);
  Future<void> showNotification(String title, String body);
}

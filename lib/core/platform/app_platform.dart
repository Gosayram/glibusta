import '../utils/platform_detector.dart';

bool get supportsMenuBar => PlatformDetector.isMacOS || PlatformDetector.isDesktop;
bool get supportsDragDrop => PlatformDetector.isDesktop;
bool get supportsDynamicColor => PlatformDetector.isAndroid;
bool get supportsWindowControls => PlatformDetector.isDesktop;
bool get supportsTextSelection => PlatformDetector.isDesktop;
bool get supportsKeyboardShortcuts => PlatformDetector.isDesktop;
bool get supportsPredictiveBack => PlatformDetector.isAndroid;
bool get hasArbitraryFileSelection => PlatformDetector.isDesktop;
bool get supportsBackgroundDownloads => PlatformDetector.isDesktop;
bool get supportsSystemNotifications => PlatformDetector.isDesktop;
bool get hasNativeMenuBar => PlatformDetector.isMacOS;
bool get supportsFileAssociations => PlatformDetector.isDesktop;
bool get canOpenFileExternally => true;
bool get needsStoragePermission => !PlatformDetector.isDesktop;

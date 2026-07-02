import '../utils/platform_detector.dart';

bool get supportsTextSelection => PlatformDetector.isDesktop;
bool get supportsPredictiveBack => PlatformDetector.isAndroid;
bool get hasNativeMenuBar => PlatformDetector.isMacOS;

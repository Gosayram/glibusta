import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/app_breakpoints.dart';

class PlatformDetector {
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isWeb => kIsWeb;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.compact &&
      MediaQuery.sizeOf(context).width < AppBreakpoints.expanded;

  static bool isDesktopWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
}
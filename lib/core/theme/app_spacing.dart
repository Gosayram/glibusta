import 'package:flutter/material.dart';

import '../platform/adaptive_context.dart';

class AppSpacing {
  AppSpacing._();

  // Base spacing unit (4px)
  static const double unit = 4.0;

  // Spacing scale
  static const double xs = unit; // 4
  static const double sm = unit * 2; // 8
  static const double md = unit * 3; // 12
  static const double lg = unit * 4; // 16
  static const double xl = unit * 5; // 20
  static const double xxl = unit * 6; // 24
  static const double xxxl = unit * 8; // 32

  // Page padding
  static const double pagePadding = lg;

  // Card padding
  static const double cardPadding = lg;

  // List item padding
  static const double listItemPadding = md;

  // Section spacing
  static const double sectionSpacing = xxl;

  // Widget spacing
  static const double widgetSpacing = lg;

  // Icon to text spacing
  static const double iconSpacing = sm;

  // App bar height
  static const double appBarHeight = 56.0;

  // Bottom navigation height
  static const double bottomNavHeight = 80.0;

  // Minimum touch target size
  static const double minTouchTarget = 48.0;
}

// Extension for responsive spacing
extension ResponsiveSpacing on BuildContext {
  double get responsiveHorizontalPadding {
    if (isCompact) return AppSpacing.lg;
    if (isExpanded) return AppSpacing.xxl;
    return AppSpacing.xl;
  }

  double get responsiveVerticalPadding {
    final height = MediaQuery.of(this).size.height;
    if (height < 600) return AppSpacing.md;
    return AppSpacing.lg;
  }
}

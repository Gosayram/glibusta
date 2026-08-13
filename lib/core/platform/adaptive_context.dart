import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

import '../utils/app_breakpoints.dart';

/// Window size class for adaptive layout decisions.
///
/// - [compact]: phones (< 600px) — bottom NavigationBar, single-column UI
/// - [medium]: foldables / small tablets (600–840px) — NavigationRail, centered content
/// - [expanded]: tablets / desktop (> 840px) — sidebar / master-detail, max-width reader
enum WindowClass { compact, medium, expanded }

/// Returns the current [WindowClass] based on screen width.
WindowClass windowClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.compact) return WindowClass.compact;
  if (width < AppBreakpoints.medium) return WindowClass.medium;
  return WindowClass.expanded;
}

/// Whether the current display can safely render the reader as a two-page spread.
///
/// The paginated reader currently owns one uninterrupted [Row] for a spread.
/// A folding feature crossing that row would place text behind a hinge or over
/// a crease, so we deliberately fall back to one page until a panel-aware
/// spread renderer is introduced. This keeps the user's two-page preference
/// intact for when the display becomes suitable again.
bool canUseTwoPageReaderMode(MediaQueryData mediaQuery) {
  final size = mediaQuery.size;
  if (size.width < 1000 || size.width < size.height) return false;

  return !mediaQuery.displayFeatures.any(
    (feature) => switch (feature.type) {
      DisplayFeatureType.fold ||
      DisplayFeatureType.hinge => _crossesReaderSpread(feature.bounds, size),
      _ => false,
    },
  );
}

bool _crossesReaderSpread(Rect bounds, Size displaySize) {
  final crossesVertically =
      bounds.height >= displaySize.height / 2 &&
      bounds.center.dx > 0 &&
      bounds.center.dx < displaySize.width;
  final crossesHorizontally =
      bounds.width >= displaySize.width / 2 &&
      bounds.center.dy > 0 &&
      bounds.center.dy < displaySize.height;
  return crossesVertically || crossesHorizontally;
}

/// Convenience extension on [BuildContext] for adaptive layout checks.
///
/// Usage:
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(context.pagePadding),
///   child: child,
/// )
/// ```
extension AdaptiveContext on BuildContext {
  /// Current window class based on screen width.
  WindowClass get windowClass => windowClassOf(this);

  /// True when screen < 600px (phone).
  bool get isCompact => windowClass == WindowClass.compact;

  /// True when screen 600–840px (foldable / small tablet).
  bool get isMedium => windowClass == WindowClass.medium;

  /// True when screen > 840px (tablet / desktop).
  bool get isExpanded => windowClass == WindowClass.expanded;

  /// True when screen width >= 1024px (macOS sidebar threshold).
  bool get isDesktopWidth => MediaQuery.sizeOf(this).width >= AppBreakpoints.desktop;

  /// True when orientation is landscape.
  bool get isLandscape => MediaQuery.orientationOf(this) == Orientation.landscape;

  /// True when screen is wide enough for two-page reader mode.
  bool get canUseTwoPageMode => canUseTwoPageReaderMode(MediaQuery.of(this));

  /// Responsive horizontal padding based on window class.
  double get pagePadding => switch (windowClass) {
    WindowClass.compact => 16,
    WindowClass.medium => 24,
    WindowClass.expanded => 32,
  };

  /// Max content width for reader based on window class.
  double get readerMaxWidth => switch (windowClass) {
    WindowClass.compact => double.infinity,
    WindowClass.medium => 720,
    WindowClass.expanded => 820,
  };

  /// Max cross-axis extent for book grid cards based on window class.
  double get bookCardMaxExtent => switch (windowClass) {
    WindowClass.compact => 140,
    WindowClass.medium => 200,
    WindowClass.expanded => 260,
  };

  /// Horizontal padding for reader based on window class.
  double get readerPadding => switch (windowClass) {
    WindowClass.compact => 20,
    WindowClass.medium => 32,
    WindowClass.expanded => 48,
  };
}

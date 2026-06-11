import 'package:flutter/material.dart';

import '../../core/platform/adaptive_context.dart';

/// A widget that builds different layouts based on [WindowClass].
///
/// Usage:
/// ```dart
/// AdaptiveBuilder(
///   compact: (_) => MobileLayout(),
///   medium: (_) => TabletLayout(),
///   expanded: (_) => DesktopLayout(),
/// )
/// ```
class AdaptiveBuilder extends StatelessWidget {
  const AdaptiveBuilder({
    required this.compact,
    required this.medium,
    required this.expanded,
    super.key,
  });

  final WidgetBuilder compact;
  final WidgetBuilder medium;
  final WidgetBuilder expanded;

  @override
  Widget build(BuildContext context) {
    return switch (context.windowClass) {
      WindowClass.compact => compact(context),
      WindowClass.medium => medium(context),
      WindowClass.expanded => expanded(context),
    };
  }
}

/// A widget that constrains content to max-width based on [WindowClass].
///
/// Used for reader and other long-content screens that benefit from
/// constrained reading width on larger screens.
class ReaderLayout extends StatelessWidget {
  const ReaderLayout({
    required this.child,
    this.maxWidth,
    this.padding,
    super.key,
  });

  final Widget child;

  /// Override max-width per window class. If null, uses [AdaptiveContext.readerMaxWidth].
  final double? maxWidth;

  /// Override padding per window class. If null, uses [AdaptiveContext.readerPadding].
  final double? padding;

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? context.readerMaxWidth;
    final effectivePadding = padding ?? context.readerPadding;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: effectivePadding),
            child: child,
          ),
        ),
      ),
    );
  }
}

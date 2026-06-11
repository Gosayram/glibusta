import 'package:flutter/material.dart';

import '../../core/platform/adaptive_context.dart';

/// Shows left/right pages side by side on wide landscape screens.
///
/// When `canUseTwoPageMode` is true (width >= 1000 + landscape),
/// renders [leftPage] and [rightPage] in a Row.
/// Otherwise, returns just [leftPage].
///
/// Usage:
/// ```dart
/// ReaderPageMode(
///   leftPage: _buildPage(leftIndex),
///   rightPage: _buildPage(rightIndex),
/// )
/// ```
class ReaderPageMode extends StatelessWidget {
  const ReaderPageMode({
    required this.leftPage,
    required this.rightPage,
    this.pageWidth = 420,
    this.spacing = 32,
    super.key,
  });

  final Widget leftPage;
  final Widget rightPage;

  /// Max width for each page column.
  final double pageWidth;

  /// Spacing between pages.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.canUseTwoPageMode) {
      return leftPage;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: pageWidth, child: leftPage),
        SizedBox(width: spacing),
        SizedBox(width: pageWidth, child: rightPage),
      ],
    );
  }
}

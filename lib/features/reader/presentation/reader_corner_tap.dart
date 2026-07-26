import 'package:flutter/widgets.dart';

import '../domain/reader.dart';

/// The four physical corners that can be assigned a tap action.
enum ReaderCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Keeps corner controls comfortably away from selectable book text while
/// remaining large enough for touch input on phones and tablets.
const readerCornerTapExtent = 72.0;

/// Returns a configured corner action, or `null` outside a corner zone.
///
/// An [CornerTapAction.inherit] result deliberately lets the existing reader
/// tap-zone behavior run unchanged.
CornerTapAction? cornerTapActionAt({
  required ReaderSettings settings,
  required Offset position,
  required Size size,
}) {
  if (size.isEmpty) return null;

  final horizontalExtent = readerCornerTapExtent.clamp(0.0, size.width / 2);
  final verticalExtent = readerCornerTapExtent.clamp(0.0, size.height / 2);
  final isLeft = position.dx <= horizontalExtent;
  final isRight = position.dx >= size.width - horizontalExtent;
  final isTop = position.dy <= verticalExtent;
  final isBottom = position.dy >= size.height - verticalExtent;

  return switch ((isLeft, isRight, isTop, isBottom)) {
    (true, _, true, _) => settings.topLeftCornerTapAction,
    (_, true, true, _) => settings.topRightCornerTapAction,
    (true, _, _, true) => settings.bottomLeftCornerTapAction,
    (_, true, _, true) => settings.bottomRightCornerTapAction,
    _ => null,
  };
}

import 'package:flutter/widgets.dart';

import '../domain/reader.dart';
import 'reader_corner_tap.dart';

/// Resolves a configured long-press action for a physical reader corner.
///
/// Unlike the global long-press detector, this resolver is used only by small
/// corner overlays. As a result, ordinary text remains owned by the selection
/// surface and can still be selected with a long press.
CornerLongPressAction? cornerLongPressActionAt({
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
    (true, _, true, _) => settings.topLeftCornerLongPressAction,
    (_, true, true, _) => settings.topRightCornerLongPressAction,
    (true, _, _, true) => settings.bottomLeftCornerLongPressAction,
    (_, true, _, true) => settings.bottomRightCornerLongPressAction,
    _ => null,
  };
}

/// Gives configured corner long presses their own gesture arena.
///
/// Only a non-[CornerLongPressAction.inherit] corner receives a recognizer.
/// This prevents the reader's configurability from registering a broad
/// long-press detector that would otherwise win over text selection.
class ReaderCornerLongPressOverlay extends StatelessWidget {
  const ReaderCornerLongPressOverlay({
    required this.settings,
    required this.onAction,
    required this.child,
    super.key,
  });

  final ReaderSettings settings;
  final ValueChanged<CornerLongPressAction> onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actions = <ReaderCorner, CornerLongPressAction>{
      ReaderCorner.topLeft: settings.topLeftCornerLongPressAction,
      ReaderCorner.topRight: settings.topRightCornerLongPressAction,
      ReaderCorner.bottomLeft: settings.bottomLeftCornerLongPressAction,
      ReaderCorner.bottomRight: settings.bottomRightCornerLongPressAction,
    };
    if (actions.values.every((action) => action == CornerLongPressAction.inherit)) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = readerCornerTapExtent.clamp(0.0, constraints.maxWidth / 2);
        final height = readerCornerTapExtent.clamp(0.0, constraints.maxHeight / 2);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            for (final entry in actions.entries)
              if (entry.value != CornerLongPressAction.inherit)
                Positioned(
                  left: switch (entry.key) {
                    ReaderCorner.topLeft || ReaderCorner.bottomLeft => 0.0,
                    ReaderCorner.topRight || ReaderCorner.bottomRight => null,
                  },
                  right: switch (entry.key) {
                    ReaderCorner.topLeft || ReaderCorner.bottomLeft => null,
                    ReaderCorner.topRight || ReaderCorner.bottomRight => 0.0,
                  },
                  top: switch (entry.key) {
                    ReaderCorner.topLeft || ReaderCorner.topRight => 0.0,
                    ReaderCorner.bottomLeft || ReaderCorner.bottomRight => null,
                  },
                  bottom: switch (entry.key) {
                    ReaderCorner.topLeft || ReaderCorner.topRight => null,
                    ReaderCorner.bottomLeft || ReaderCorner.bottomRight => 0.0,
                  },
                  width: width,
                  height: height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: () => onAction(entry.value),
                    child: const SizedBox.expand(),
                  ),
                ),
          ],
        );
      },
    );
  }
}

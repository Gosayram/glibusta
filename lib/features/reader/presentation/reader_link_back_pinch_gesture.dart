import 'package:flutter/gestures.dart';

/// Recognises a deliberate inward two-finger pinch for returning from a link.
///
/// It deliberately ignores outward, one-finger and weak scale changes so
/// ordinary font-size pinch handling remains available. Navigation ownership
/// stays with the reader controller: without a saved link position the caller
/// performs a controlled no-op.
final class ReaderLinkBackPinchGesture {
  static const _maximumBackScale = 0.8;

  bool _hasTriggered = false;

  void start(ScaleStartDetails _) {
    _hasTriggered = false;
  }

  bool update(ScaleUpdateDetails details) {
    if (_hasTriggered || details.pointerCount != 2) return false;

    if (details.scale > _maximumBackScale) return false;

    _hasTriggered = true;
    return true;
  }

  void end(ScaleEndDetails _) {
    _hasTriggered = false;
  }
}

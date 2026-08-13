import 'package:flutter/gestures.dart';

/// The chapter direction recognised from a two-finger vertical gesture.
enum TwoFingerChapterDirection { previous, next }

/// Recognises a deliberate two-finger vertical swipe without consuming a pinch.
///
/// A scale change always wins over chapter navigation. This keeps the helper
/// compatible with current and future font-size pinch handling: only two
/// parallel fingers moving vertically by at least [_minimumSwipeDistance]
/// can produce a chapter change.
final class ReaderTwoFingerChapterGesture {
  static const _minimumSwipeDistance = 72.0;
  static const _maximumScaleDelta = 0.04;

  Offset? _start;
  bool _isPinching = false;
  bool _hasNavigated = false;

  void start(ScaleStartDetails details) {
    _start = details.localFocalPoint;
    _isPinching = false;
    _hasNavigated = false;
  }

  TwoFingerChapterDirection? update(ScaleUpdateDetails details) {
    if (_hasNavigated || details.pointerCount != 2) return null;

    final hasScaleChange =
        (details.scale - 1).abs() > _maximumScaleDelta ||
        (details.horizontalScale - 1).abs() > _maximumScaleDelta ||
        (details.verticalScale - 1).abs() > _maximumScaleDelta;
    if (hasScaleChange) {
      _isPinching = true;
      return null;
    }
    if (_isPinching) return null;

    final start = _start;
    if (start == null) return null;
    final delta = details.localFocalPoint - start;
    if (delta.dy.abs() < _minimumSwipeDistance || delta.dy.abs() <= delta.dx.abs()) {
      return null;
    }

    _hasNavigated = true;
    return delta.dy < 0 ? TwoFingerChapterDirection.next : TwoFingerChapterDirection.previous;
  }

  void end(ScaleEndDetails details) {
    _start = null;
    _isPinching = false;
    _hasNavigated = false;
  }
}

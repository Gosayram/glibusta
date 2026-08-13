import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_link_back_pinch_gesture.dart';

void main() {
  group('ReaderLinkBackPinchGesture', () {
    test('recognises one deliberate inward two-finger pinch', () {
      final gesture = ReaderLinkBackPinchGesture()..start(ScaleStartDetails());

      expect(
        gesture.update(
          ScaleUpdateDetails(
            pointerCount: 2,
            scale: 0.78,
          ),
        ),
        isTrue,
      );
      expect(
        gesture.update(
          ScaleUpdateDetails(
            pointerCount: 2,
            scale: 0.7,
            horizontalScale: 0.7,
            verticalScale: 0.7,
          ),
        ),
        isFalse,
      );
    });

    test('leaves outward, weak, and non-two-finger scales alone', () {
      final gesture = ReaderLinkBackPinchGesture()..start(ScaleStartDetails());

      for (final details in [
        ScaleUpdateDetails(pointerCount: 2, scale: 1.2, horizontalScale: 1.2, verticalScale: 1.2),
        ScaleUpdateDetails(pointerCount: 2, scale: 0.9, horizontalScale: 0.9, verticalScale: 0.9),
        ScaleUpdateDetails(pointerCount: 1, scale: 0.7, horizontalScale: 0.7, verticalScale: 0.7),
      ]) {
        expect(gesture.update(details), isFalse);
      }
    });

    test('allows another pinch after the gesture ends', () {
      final gesture = ReaderLinkBackPinchGesture()..start(ScaleStartDetails());
      expect(
        gesture.update(
          ScaleUpdateDetails(
            pointerCount: 2,
            scale: 0.8,
            horizontalScale: 0.8,
            verticalScale: 0.8,
          ),
        ),
        isTrue,
      );

      gesture.end(ScaleEndDetails());
      gesture.start(ScaleStartDetails());

      expect(
        gesture.update(
          ScaleUpdateDetails(
            pointerCount: 2,
            scale: 0.75,
            horizontalScale: 0.75,
            verticalScale: 0.75,
          ),
        ),
        isTrue,
      );
    });
  });
}

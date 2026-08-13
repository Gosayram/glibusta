import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_two_finger_chapter_gesture.dart';

void main() {
  group('ReaderTwoFingerChapterGesture', () {
    test('recognises one deliberate two-finger vertical swipe once', () {
      final gesture = ReaderTwoFingerChapterGesture()
        ..start(ScaleStartDetails(localFocalPoint: const Offset(100, 200)));

      expect(
        gesture.update(
          ScaleUpdateDetails(
            localFocalPoint: const Offset(100, 110),
            pointerCount: 2,
          ),
        ),
        TwoFingerChapterDirection.next,
      );
      expect(
        gesture.update(
          ScaleUpdateDetails(
            localFocalPoint: const Offset(100, 80),
            pointerCount: 2,
          ),
        ),
        isNull,
      );
    });

    test('does not turn a chapter for a pinch, horizontal, or non-two-finger gesture', () {
      final gesture = ReaderTwoFingerChapterGesture();

      gesture.start(ScaleStartDetails(localFocalPoint: const Offset(100, 200)));
      expect(
        gesture.update(
          ScaleUpdateDetails(
            localFocalPoint: const Offset(100, 100),
            pointerCount: 2,
            scale: 1.1,
          ),
        ),
        isNull,
      );

      gesture.start(ScaleStartDetails(localFocalPoint: const Offset(100, 200)));
      expect(
        gesture.update(
          ScaleUpdateDetails(
            localFocalPoint: const Offset(190, 190),
            pointerCount: 2,
          ),
        ),
        isNull,
      );

      gesture.start(ScaleStartDetails(localFocalPoint: const Offset(100, 200)));
      expect(
        gesture.update(
          ScaleUpdateDetails(
            localFocalPoint: const Offset(100, 100),
            pointerCount: 1,
          ),
        ),
        isNull,
      );
    });
  });
}

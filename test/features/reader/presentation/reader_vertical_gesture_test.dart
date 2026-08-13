import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_vertical_gesture.dart';

void main() {
  test('left vertical drag adjusts brightness within its safe range', () {
    expect(
      readerBrightnessForVerticalDrag(startBrightness: 0.8, deltaY: -100),
      closeTo(1.0, 0.001),
    );
    expect(
      readerBrightnessForVerticalDrag(startBrightness: 0.3, deltaY: 200),
      0.2,
    );
  });

  test('right vertical drag adjusts warmth without changing its bounds', () {
    expect(
      readerWarmthForVerticalDrag(startWarmth: 0.2, deltaY: -100),
      closeTo(0.4, 0.001),
    );
    expect(readerWarmthForVerticalDrag(startWarmth: 0.9, deltaY: -100), 1.0);
  });
}

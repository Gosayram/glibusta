import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('reader backgrounds are defined', () {
      expect(AppColors.readerDay, isNotNull);
      expect(AppColors.readerNight, isNotNull);
      expect(AppColors.readerSepia, isNotNull);
      expect(AppColors.readerOledBlack, isNotNull);
      expect(AppColors.readerPaper, isNotNull);
    });

    test('semantic colors are defined', () {
      expect(AppColors.success, isNotNull);
      expect(AppColors.warning, isNotNull);
      expect(AppColors.error, isNotNull);
      expect(AppColors.info, isNotNull);
    });

    test('reader OLED black is pure black', () {
      expect(AppColors.readerOledBlack.toARGB32(), 0xFF000000);
    });

    test('reader night is dark', () {
      final brightness = AppColors.readerNight.computeLuminance();
      expect(brightness, lessThan(0.2));
    });

    test('reader day is light', () {
      final brightness = AppColors.readerDay.computeLuminance();
      expect(brightness, greaterThan(0.5));
    });

    test('reader sepia is warm', () {
      final color = AppColors.readerSepia;
      expect(color.r, greaterThan(color.b));
    });
  });
}

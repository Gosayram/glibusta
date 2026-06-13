import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('primary colors are defined', () {
      expect(AppColors.primary, isNotNull);
      expect(AppColors.primaryDark, isNotNull);
    });

    test('background colors are defined', () {
      expect(AppColors.backgroundLight, isNotNull);
      expect(AppColors.backgroundDark, isNotNull);
    });

    test('surface colors are defined', () {
      expect(AppColors.surfaceLight, isNotNull);
      expect(AppColors.surfaceDark, isNotNull);
    });

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

    test('text colors are defined', () {
      expect(AppColors.textPrimaryLight, isNotNull);
      expect(AppColors.textSecondaryLight, isNotNull);
      expect(AppColors.textPrimaryDark, isNotNull);
      expect(AppColors.textSecondaryDark, isNotNull);
    });

    test('divider colors are defined', () {
      expect(AppColors.dividerLight, isNotNull);
      expect(AppColors.dividerDark, isNotNull);
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

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('unit is 4.0', () {
      expect(AppSpacing.unit, 4.0);
    });

    test('xs equals unit', () {
      expect(AppSpacing.xs, AppSpacing.unit);
    });

    test('sm equals 2 * unit', () {
      expect(AppSpacing.sm, 8.0);
    });

    test('md equals 3 * unit', () {
      expect(AppSpacing.md, 12.0);
    });

    test('lg equals 4 * unit', () {
      expect(AppSpacing.lg, 16.0);
    });

    test('xl equals 5 * unit', () {
      expect(AppSpacing.xl, 20.0);
    });

    test('xxl equals 6 * unit', () {
      expect(AppSpacing.xxl, 24.0);
    });

    test('xxxl equals 8 * unit', () {
      expect(AppSpacing.xxxl, 32.0);
    });

    test('pagePadding equals lg', () {
      expect(AppSpacing.pagePadding, AppSpacing.lg);
    });

    test('cardPadding equals lg', () {
      expect(AppSpacing.cardPadding, AppSpacing.lg);
    });

    test('listItemPadding equals md', () {
      expect(AppSpacing.listItemPadding, AppSpacing.md);
    });

    test('sectionSpacing equals xxl', () {
      expect(AppSpacing.sectionSpacing, AppSpacing.xxl);
    });

    test('widgetSpacing equals lg', () {
      expect(AppSpacing.widgetSpacing, AppSpacing.lg);
    });

    test('iconSpacing equals sm', () {
      expect(AppSpacing.iconSpacing, AppSpacing.sm);
    });

    test('appBarHeight is 56', () {
      expect(AppSpacing.appBarHeight, 56.0);
    });

    test('bottomNavHeight is 80', () {
      expect(AppSpacing.bottomNavHeight, 80.0);
    });

    test('minTouchTarget is 48', () {
      expect(AppSpacing.minTouchTarget, 48.0);
    });
  });
}

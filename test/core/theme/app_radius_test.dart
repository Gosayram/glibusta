import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_radius.dart';

void main() {
  group('AppRadius', () {
    test('scale values', () {
      expect(AppRadius.xs, 4.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 24.0);
      expect(AppRadius.xxl, 32.0);
      expect(AppRadius.full, 999.0);
    });

    test('borderRadiusXs', () {
      expect(AppRadius.borderRadiusXs, const BorderRadius.all(Radius.circular(4)));
    });

    test('borderRadiusSm', () {
      expect(AppRadius.borderRadiusSm, const BorderRadius.all(Radius.circular(8)));
    });

    test('borderRadiusMd', () {
      expect(AppRadius.borderRadiusMd, const BorderRadius.all(Radius.circular(12)));
    });

    test('borderRadiusLg', () {
      expect(AppRadius.borderRadiusLg, const BorderRadius.all(Radius.circular(16)));
    });

    test('borderRadiusXl', () {
      expect(AppRadius.borderRadiusXl, const BorderRadius.all(Radius.circular(24)));
    });

    test('borderRadiusXxl', () {
      expect(AppRadius.borderRadiusXxl, const BorderRadius.all(Radius.circular(32)));
    });

    test('borderRadiusFull', () {
      expect(AppRadius.borderRadiusFull, const BorderRadius.all(Radius.circular(999)));
    });

    test('component radii use correct values', () {
      expect(AppRadius.cardRadius, AppRadius.borderRadiusMd);
      expect(AppRadius.buttonRadius, AppRadius.borderRadiusSm);
      expect(AppRadius.dialogRadius, AppRadius.borderRadiusLg);
      expect(AppRadius.inputRadius, AppRadius.borderRadiusSm);
      expect(AppRadius.chipRadius, AppRadius.borderRadiusXs);
      expect(AppRadius.bottomSheetRadius, AppRadius.borderRadiusXl);
    });
  });
}

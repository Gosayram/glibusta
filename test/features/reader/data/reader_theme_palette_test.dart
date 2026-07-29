import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_colors.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('reader theme palette', () {
    test('every built-in theme has a reader-facing label and readable body text', () {
      for (final theme in ReaderTheme.values) {
        final colors = ReaderColors.forTheme(theme);

        expect(theme.displayName, isNotEmpty);
        expect(colors.preview.textContrast, greaterThanOrEqualTo(4.5));
      }
    });

    test('system preview follows the platform brightness', () {
      final light = ReaderColors.forThemeWithContext(ReaderTheme.system, Brightness.light);
      final dark = ReaderColors.forThemeWithContext(ReaderTheme.system, Brightness.dark);

      expect(light.scaffold, isNot(dark.scaffold));
      expect(light.scaffold, Colors.white);
      expect(dark.scaffold, const Color(0xFF111318));
    });
  });
}

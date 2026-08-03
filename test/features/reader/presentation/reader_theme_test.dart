import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_colors.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('Sepia theme colors', () {
    test('scaffold is warm parchment', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.scaffold, const Color(0xFFF4ecd8));
    });

    test('text is dark brown', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.text, const Color(0xFF5B4636));
    });

    test('link is brown', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.link, const Color(0xFF795548));
    });

    test('highlight is warm amber', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.highlight, const Color(0x33FFB74D));
    });

    test('footnote is muted brown', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.footnote, const Color(0xFF8D7355));
    });

    test('accent is deep brown', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.accent, const Color(0xFF6D4C41));
    });

    test('text contrast against scaffold meets WCAG AA', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.preview.textContrast, greaterThanOrEqualTo(4.5));
    });

    test('link contrast against scaffold meets WCAG AA', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.preview.linkContrast, greaterThanOrEqualTo(4.5));
    });
  });

  group('Contrast ratio calculation', () {
    test('black on white has maximum contrast ~21:1', () {
      final ratio = ReaderColorContrast.ratio(Colors.black, Colors.white);
      expect(ratio, closeTo(21, 0.001));
    });

    test('white on white has minimum contrast 1:1', () {
      final ratio = ReaderColorContrast.ratio(Colors.white, Colors.white);
      expect(ratio, closeTo(1, 0.001));
    });

    test('WCAG AA threshold is 4.5:1', () {
      final ratio = ReaderColorContrast.ratio(Colors.black87, Colors.white);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('works with translucent colors via alpha blending', () {
      final ratio = ReaderColorContrast.ratio(
        Colors.black.withValues(alpha: 0.5),
        Colors.white,
      );
      expect(ratio, greaterThan(1));
    });
  });

  group('Theme switching preserves per-book settings', () {
    test('all built-in themes have valid ReaderColors', () {
      for (final theme in ReaderTheme.values) {
        final colors = ReaderColors.forTheme(theme);
        expect(colors.scaffold, isNotNull);
        expect(colors.text, isNotNull);
        expect(colors.link, isNotNull);
        expect(colors.preview.textContrast, greaterThanOrEqualTo(4.5));
      }
    });

    test('forThemeWithContext system theme follows brightness', () {
      final light = ReaderColors.forThemeWithContext(
        ReaderTheme.system,
        Brightness.light,
      );
      final dark = ReaderColors.forThemeWithContext(
        ReaderTheme.system,
        Brightness.dark,
      );
      expect(light.scaffold, Colors.white);
      expect(dark.scaffold, const Color(0xFF111318));
    });

    test('non-system themes ignore brightness', () {
      final light = ReaderColors.forThemeWithContext(
        ReaderTheme.sepia,
        Brightness.light,
      );
      final dark = ReaderColors.forThemeWithContext(
        ReaderTheme.sepia,
        Brightness.dark,
      );
      expect(light.scaffold, dark.scaffold);
    });
  });

  group('Low-contrast warning indicator', () {
    test('preview detects low contrast below WCAG AA', () {
      final preview = ReaderColorPreview.fromColors(
        background: const Color(0xFFF0E0C0),
        text: const Color(0xFFD4A574),
        link: const Color(0xFFD4A574),
      );
      expect(preview.textContrast, lessThan(4.5));
    });

    test('preview passes for high contrast combinations', () {
      final preview = ReaderColorPreview.fromColors(
        background: Colors.white,
        text: Colors.black87,
        link: const Color(0xFF1565C0),
      );
      expect(preview.textContrast, greaterThanOrEqualTo(4.5));
    });
  });
}

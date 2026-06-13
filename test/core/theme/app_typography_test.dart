import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_typography.dart';

void main() {
  group('AppTypography', () {
    group('display styles', () {
      test('displayLarge has fontSize 57', () {
        final style = AppTypography.displayLarge(isDark: false);
        expect(style.fontSize, 57);
        expect(style.fontFamily, 'Inter');
      });

      test('displayMedium has fontSize 45', () {
        final style = AppTypography.displayMedium(isDark: true);
        expect(style.fontSize, 45);
        expect(style.color, isNotNull);
      });

      test('displaySmall has fontSize 36', () {
        final style = AppTypography.displaySmall(isDark: false);
        expect(style.fontSize, 36);
      });
    });

    group('headline styles', () {
      test('headlineLarge has fontSize 32', () {
        expect(AppTypography.headlineLarge(isDark: false).fontSize, 32);
      });

      test('headlineMedium has fontSize 28', () {
        expect(AppTypography.headlineMedium(isDark: true).fontSize, 28);
      });

      test('headlineSmall has fontSize 24', () {
        expect(AppTypography.headlineSmall(isDark: false).fontSize, 24);
      });
    });

    group('title styles', () {
      test('titleLarge has fontSize 22 and weight w500', () {
        final s = AppTypography.titleLarge(isDark: false);
        expect(s.fontSize, 22);
        expect(s.fontWeight, FontWeight.w500);
      });

      test('titleMedium has fontSize 16 and weight w500', () {
        final s = AppTypography.titleMedium(isDark: true);
        expect(s.fontSize, 16);
        expect(s.fontWeight, FontWeight.w500);
      });

      test('titleSmall has weight w500', () {
        final s = AppTypography.titleSmall(isDark: false);
        expect(s.fontWeight, FontWeight.w500);
      });
    });

    group('body styles', () {
      test('bodyLarge has fontSize 16', () {
        expect(AppTypography.bodyLarge(isDark: false).fontSize, 16);
      });

      test('bodyMedium default fontSize is 14', () {
        expect(AppTypography.bodyMedium(isDark: true).fontSize, 14);
      });

      test('bodySmall has fontSize 12', () {
        final s = AppTypography.bodySmall(isDark: false);
        expect(s.fontSize, 12);
      });
    });

    group('dark mode', () {
      test('light mode uses black87', () {
        final s = AppTypography.bodyLarge(isDark: false);
        expect(s.color, Colors.black87);
      });

      test('dark mode uses white', () {
        final s = AppTypography.bodyLarge(isDark: true);
        expect(s.color, Colors.white);
      });

      test('bodySmall light uses black54', () {
        final s = AppTypography.bodySmall(isDark: false);
        expect(s.color, Colors.black54);
      });

      test('bodySmall dark uses white70', () {
        final s = AppTypography.bodySmall(isDark: true);
        expect(s.color, Colors.white70);
      });
    });

    group('reader styles', () {
      test('readerBody defaults to Literata', () {
        final s = AppTypography.readerBody(isDark: false);
        expect(s.fontFamily, 'Literata');
        expect(s.fontSize, 18);
        expect(s.height, 1.6);
      });

      test('readerBody custom fontSize', () {
        final s = AppTypography.readerBody(isDark: true, fontSize: 24);
        expect(s.fontSize, 24);
      });

      test('readerBody custom fontFamily', () {
        final s = AppTypography.readerBody(isDark: false, fontFamily: 'Inter');
        expect(s.fontFamily, 'Inter');
      });

      test('readerTitle defaults', () {
        final s = AppTypography.readerTitle(isDark: false);
        expect(s.fontFamily, 'Literata');
        expect(s.fontSize, 24);
        expect(s.fontWeight, FontWeight.w600);
      });

      test('readerChapter defaults', () {
        final s = AppTypography.readerChapter(isDark: true);
        expect(s.fontFamily, 'Literata');
        expect(s.fontSize, 20);
        expect(s.fontWeight, FontWeight.w500);
      });

      test('readerTitle with Inter font', () {
        final s = AppTypography.readerTitle(isDark: false, fontFamily: 'Inter');
        expect(s.fontFamily, 'Inter');
      });
    });

    test('availableReaderFonts contains Literata and Inter', () {
      expect(AppTypography.availableReaderFonts, contains('Literata'));
      expect(AppTypography.availableReaderFonts, contains('Inter'));
      expect(AppTypography.availableReaderFonts.length, 2);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_colors.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderColors.forTheme', () {
    test('system and light use white background', () {
      final light = ReaderColors.forTheme(ReaderTheme.system);
      final system = ReaderColors.forTheme(ReaderTheme.light);
      expect(light.scaffold, Colors.white);
      expect(system.scaffold, Colors.white);
    });

    test('paper uses warm beige', () {
      final colors = ReaderColors.forTheme(ReaderTheme.paper);
      expect(colors.scaffold, const Color(0xFFF5F0E6));
    });

    test('sepia uses warm tan', () {
      final colors = ReaderColors.forTheme(ReaderTheme.sepia);
      expect(colors.scaffold, const Color(0xFFF4ecd8));
    });

    test('dark uses dark gray', () {
      final colors = ReaderColors.forTheme(ReaderTheme.dark);
      expect(colors.scaffold, const Color(0xFF111318));
    });

    test('oled uses pure black', () {
      final colors = ReaderColors.forTheme(ReaderTheme.oled);
      expect(colors.scaffold, Colors.black);
    });

    test('bedtime uses warm dark', () {
      final colors = ReaderColors.forTheme(ReaderTheme.bedtime);
      expect(colors.scaffold, const Color(0xFF1A1612));
    });
  });

  group('ReaderColors.progressColor', () {
    test('light theme uses blue shade 700', () {
      final color = ReaderColors.progressColor(ReaderTheme.light);
      expect(color, Colors.blue.shade700);
    });

    test('dark theme uses blue shade 300', () {
      final color = ReaderColors.progressColor(ReaderTheme.dark);
      expect(color, Colors.blue.shade300);
    });

    test('paper uses brown', () {
      final color = ReaderColors.progressColor(ReaderTheme.paper);
      expect(color, const Color(0xFF5B4636));
    });

    test('bedtime uses warm cream', () {
      final color = ReaderColors.progressColor(ReaderTheme.bedtime);
      expect(color, const Color(0xFFD7CDBF));
    });
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/color_preset_service.dart';
import 'package:glibusta/features/reader/data/reader_colors.dart';

void main() {
  group('ColorPreset JSON round-trip', () {
    test('serializes and deserializes with link/highlight', () {
      const preset = ColorPreset(
        id: 'custom_1',
        name: 'Dark Blue',
        backgroundColor: Color(0xFF0A1628),
        fontColor: Color(0xFF8ECAE6),
        linkColor: Color(0xFF48CAE4),
        highlightColor: Color(0x4000FF00),
        order: 3,
      );
      final json = preset.toJson();
      final restored = ColorPreset.fromJson(json);

      expect(restored.id, preset.id);
      expect(restored.name, preset.name);
      expect(restored.backgroundColor, preset.backgroundColor);
      expect(restored.fontColor, preset.fontColor);
      expect(restored.linkColor, preset.linkColor);
      expect(restored.highlightColor, preset.highlightColor);
      expect(restored.order, preset.order);
    });

    test('deserializes legacy presets without link/highlight', () {
      final json = {
        'id': 'old',
        'name': 'Legacy',
        'backgroundColor': 4278190080,
        'fontColor': 4294967295,
        'order': 0,
      };
      final preset = ColorPreset.fromJson(json);

      expect(preset.linkColor, isNull);
      expect(preset.highlightColor, isNull);
    });

    test('copyWith clears link/highlight when requested', () {
      const preset = ColorPreset(
        id: 'x',
        name: 'X',
        backgroundColor: Color(0xFFFFFFFF),
        fontColor: Color(0xFF000000),
        linkColor: Color(0xFF0000FF),
        highlightColor: Color(0x40FFFF00),
      );
      final cleared = preset.copyWith(clearLinkColor: true, clearHighlightColor: true);

      expect(cleared.linkColor, isNull);
      expect(cleared.highlightColor, isNull);
      expect(cleared.backgroundColor, preset.backgroundColor);
    });
  });

  group('ReaderColors.fromPreset', () {
    test('uses provided link and highlight colors', () {
      final colors = ReaderColors.fromPreset(
        const Color(0xFF0A1628),
        const Color(0xFF8ECAE6),
        linkColor: const Color(0xFF48CAE4),
        highlightColor: const Color(0x4000FF00),
      );

      expect(colors.link, const Color(0xFF48CAE4));
      expect(colors.highlight, const Color(0x4000FF00));
      expect(colors.scaffold, const Color(0xFF0A1628));
      expect(colors.text, const Color(0xFF8ECAE6));
      expect(colors.accent, const Color(0xFF48CAE4)); // accent follows link
    });

    test('falls back to defaults when not provided', () {
      final colors = ReaderColors.fromPreset(
        const Color(0xFF111318),
        const Color(0xFFE6E1E5),
      );

      expect(colors.link, Colors.blue);
      expect(colors.highlight, const Color(0x40FFEB3B));
    });
  });

  group('Contrast ratio calculation', () {
    test('high contrast passes WCAG AA', () {
      final preview = ReaderColorPreview.fromColors(
        background: const Color(0xFFFFFFFF),
        text: const Color(0xFF000000),
        link: const Color(0xFF0000FF),
      );
      expect(preview.textContrast, greaterThanOrEqualTo(4.5));
      expect(preview.linkContrast, greaterThanOrEqualTo(4.5));
    });

    test('low contrast triggers warning', () {
      final preview = ReaderColorPreview.fromColors(
        background: const Color(0xFFCCCCCC),
        text: const Color(0xFFBBBBBB),
        link: const Color(0xFFBBBBBB),
      );
      expect(preview.textContrast, lessThan(4.5));
    });

    test('semantics label includes both ratios', () {
      final preview = ReaderColorPreview.fromColors(
        background: Colors.white,
        text: Colors.black,
        link: Colors.blue.shade700,
      );
      expect(preview.semanticLabel, contains('Контраст текста'));
      expect(preview.semanticLabel, contains('Контраст ссылок'));
    });
  });

  group('Preset deletion', () {
    test('removing a preset by id excludes it', () {
      var presets = [
        const ColorPreset(
          id: 'a',
          name: 'A',
          backgroundColor: Colors.white,
          fontColor: Colors.black,
        ),
        const ColorPreset(
          id: 'b',
          name: 'B',
          backgroundColor: Colors.black,
          fontColor: Colors.white,
        ),
      ];
      presets = presets.where((p) => p.id != 'a').toList();

      expect(presets.length, 1);
      expect(presets.first.id, 'b');
    });

    test('fallback preset id selection skips deleted', () {
      final presets = [
        const ColorPreset(
          id: 'blue_light',
          name: 'Blue',
          backgroundColor: Colors.white,
          fontColor: Colors.black,
        ),
        const ColorPreset(
          id: 'dark',
          name: 'Dark',
          backgroundColor: Colors.black,
          fontColor: Colors.white,
        ),
      ];
      final existingId = 'dark';

      var fallbackId = 'blue_light';
      for (final p in presets) {
        if (p.id != existingId) {
          fallbackId = p.id;
          break;
        }
      }
      expect(fallbackId, 'blue_light');
    });
  });

  group('JSON persistence format', () {
    test('matches expected schema for custom presets', () {
      const preset = ColorPreset(
        id: 'custom_123',
        name: 'Dark Blue',
        backgroundColor: Color(0xFF0A1628),
        fontColor: Color(0xFF8ECAE6),
        linkColor: Color(0xFF48CAE4),
      );
      final json = preset.toJson();

      expect(json['id'], 'custom_123');
      expect(json['name'], 'Dark Blue');
      expect(json['backgroundColor'], 0xFF0A1628);
      expect(json['fontColor'], 0xFF8ECAE6);
      expect(json['linkColor'], 0xFF48CAE4);
      expect(json.containsKey('highlightColor'), isFalse);

      final encoded = jsonEncode([json]);
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final restored = ColorPreset.fromJson(decoded.first as Map<String, dynamic>);
      expect(restored.linkColor, const Color(0xFF48CAE4));
    });
  });
}

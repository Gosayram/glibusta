import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/color_preset_service.dart';
import 'package:glibusta/features/reader/data/reader_colors.dart';

ReaderColors? resolveCustomColors({
  required List<ColorPreset>? presets,
  required String activePresetId,
  required List<ColorPreset>? Function() getCachedPresets,
  required String? Function() getCachedPresetId,
  required ReaderColors? Function() getCachedColors,
  required void Function(List<ColorPreset>, String, ReaderColors?) setCache,
}) {
  if (presets == null) return null;
  if (identical(presets, getCachedPresets()) && activePresetId == getCachedPresetId()) {
    return getCachedColors();
  }
  ReaderColors? result;
  try {
    final preset = presets.firstWhere((p) => p.id == activePresetId);
    result = ReaderColors.fromPreset(
      preset.backgroundColor,
      preset.fontColor,
      linkColor: preset.linkColor,
      highlightColor: preset.highlightColor,
    );
  } on Object catch (_) {
    result = null;
  }
  setCache(presets, activePresetId, result);
  return result;
}

void main() {
  group('Custom colors cache', () {
    late List<ColorPreset>? cachedPresets;
    late String? cachedPresetId;
    late ReaderColors? cachedColors;

    setUp(() {
      cachedPresets = null;
      cachedPresetId = null;
      cachedColors = null;
    });

    ReaderColors? callResolve({
      required List<ColorPreset>? presets,
      required String activePresetId,
    }) {
      return resolveCustomColors(
        presets: presets,
        activePresetId: activePresetId,
        getCachedPresets: () => cachedPresets,
        getCachedPresetId: () => cachedPresetId,
        getCachedColors: () => cachedColors,
        setCache: (p, id, c) {
          cachedPresets = p;
          cachedPresetId = id;
          cachedColors = c;
        },
      );
    }

    test('returns null when presets list is null', () {
      final result = callResolve(
        presets: null,
        activePresetId: 'blue_light',
      );
      expect(result, isNull);
    });

    test('returns null when preset ID not found', () {
      final presets = [
        const ColorPreset(
          id: 'blue_light',
          name: 'Blue',
          backgroundColor: Color(0xFFFAF8FF),
          fontColor: Color(0xFF44464F),
        ),
      ];
      final result = callResolve(
        presets: presets,
        activePresetId: 'nonexistent',
      );
      expect(result, isNull);
    });

    test('returns cached colors when presets and ID unchanged', () {
      final presets = [
        const ColorPreset(
          id: 'blue_light',
          name: 'Blue',
          backgroundColor: Color(0xFFFAF8FF),
          fontColor: Color(0xFF44464F),
        ),
      ];
      final first = callResolve(
        presets: presets,
        activePresetId: 'blue_light',
      );
      expect(first, isNotNull);
      expect(first!.scaffold, const Color(0xFFFAF8FF));

      final second = callResolve(
        presets: presets,
        activePresetId: 'blue_light',
      );
      expect(identical(first, second), isTrue);
    });

    test('recomputes when active preset ID changes', () {
      final presets = [
        const ColorPreset(
          id: 'blue_light',
          name: 'Blue',
          backgroundColor: Color(0xFFFAF8FF),
          fontColor: Color(0xFF44464F),
        ),
        const ColorPreset(
          id: 'dark',
          name: 'Dark',
          backgroundColor: Color(0xFF111318),
          fontColor: Color(0xFFE6E1E5),
        ),
      ];
      final first = callResolve(
        presets: presets,
        activePresetId: 'blue_light',
      );
      expect(first, isNotNull);
      expect(first!.scaffold, const Color(0xFFFAF8FF));

      final second = callResolve(
        presets: presets,
        activePresetId: 'dark',
      );
      expect(second, isNotNull);
      expect(second!.scaffold, const Color(0xFF111318));
      expect(identical(first, second), isFalse);
    });

    test('recomputes when preset list reference changes', () {
      final presets1 = [
        const ColorPreset(
          id: 'blue_light',
          name: 'Blue',
          backgroundColor: Color(0xFFFAF8FF),
          fontColor: Color(0xFF44464F),
        ),
      ];
      final first = callResolve(
        presets: presets1,
        activePresetId: 'blue_light',
      );
      expect(first, isNotNull);

      final presets2 = [
        const ColorPreset(
          id: 'blue_light',
          name: 'Blue Updated',
          backgroundColor: Color(0xFFEEEEEE),
          fontColor: Color(0xFF222222),
        ),
      ];
      final second = callResolve(
        presets: presets2,
        activePresetId: 'blue_light',
      );
      expect(second, isNotNull);
      expect(second!.scaffold, const Color(0xFFEEEEEE));
      expect(identical(first, second), isFalse);
    });

    test('passes link and highlight colors from preset', () {
      final presets = [
        const ColorPreset(
          id: 'custom',
          name: 'My Blue',
          backgroundColor: Color(0xFF0A1628),
          fontColor: Color(0xFF8ECAE6),
          linkColor: Color(0xFF48CAE4),
          highlightColor: Color(0x4000FF00),
        ),
      ];
      final result = callResolve(
        presets: presets,
        activePresetId: 'custom',
      );
      expect(result, isNotNull);
      expect(result!.link, const Color(0xFF48CAE4));
      expect(result.highlight, const Color(0x4000FF00));
    });

    test('falls back to defaults when link/highlight not set', () {
      final presets = [
        const ColorPreset(
          id: 'legacy',
          name: 'Legacy',
          backgroundColor: Color(0xFF111318),
          fontColor: Color(0xFFE6E1E5),
        ),
      ];
      final result = callResolve(
        presets: presets,
        activePresetId: 'legacy',
      );
      expect(result, isNotNull);
      expect(result!.link, Colors.blue);
      expect(result.highlight, const Color(0x40FFEB3B));
    });
  });
}

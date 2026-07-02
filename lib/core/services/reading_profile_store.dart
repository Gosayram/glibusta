import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/reader/domain/reader.dart';

/// MD-11.1: User-defined reading profiles.
/// Stores named snapshots of ReaderSettings in SharedPreferences.
class ReadingProfileStore {
  static const _key = 'reading_profiles';

  static Future<List<String>> listNames() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.keys.toList()..sort();
    } on Object {
      return [];
    }
  }

  static Future<void> save(String name, ReaderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _readMap(prefs);
    map[name] = _toMap(s);
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<ReaderSettings?> load(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _readMap(prefs);
    final m = map[name];
    if (m == null) return null;
    try {
      return _fromMap(m as Map<String, dynamic>);
    } on Object catch (e) {
      debugPrint('Profile load failed: $e');
      return null;
    }
  }

  static Future<void> delete(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _readMap(prefs);
    map.remove(name);
    await prefs.setString(_key, jsonEncode(map));
  }

  static Map<String, dynamic> _readMap(SharedPreferences prefs) {
    final json = prefs.getString(_key);
    if (json == null) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }

  static Map<String, dynamic> _toMap(ReaderSettings s) => {
    'theme': s.theme.name,
    'mode': s.mode.name,
    'fontSize': s.fontSize,
    'lineHeight': s.lineHeight,
    'margin': s.margin,
    'font': s.font.name,
    'paragraphSpacing': s.paragraphSpacing,
    'letterSpacing': s.letterSpacing,
    'wordSpacing': s.wordSpacing,
    'fontWeightDelta': s.fontWeightDelta,
    'textAlign': s.textAlign.name,
    'autoThemeMode': s.autoThemeMode.name,
    'customDayHour': s.customDayHour,
    'customNightHour': s.customNightHour,
    'brightness': s.brightness,
    'warmth': s.warmth,
    'keepScreenAwake': s.keepScreenAwake,
    'autoHideDelay': s.autoHideDelay,
    'paragraphFirstLineIndent': s.paragraphFirstLineIndent,
    'hyphenation': s.hyphenation,
    'oldStyleFigures': s.oldStyleFigures,
    'smallCaps': s.smallCaps,
    'rsvpWpm': s.rsvpWpm,
    'ignoreBookAlignment': s.ignoreBookAlignment,
    'ignoreBookIndent': s.ignoreBookIndent,
    'pageTurnAnimation': s.pageTurnAnimation.name,
    'textDirection': s.textDirection.name,
    'readerWidth': s.readerWidth,
    'verticalSwipeBrightness': s.verticalSwipeBrightness,
    'customCss': s.customCss,
  };

  static T _enum<T extends Enum>(dynamic v, List<T> values, T fallback) {
    if (v is String) {
      for (final e in values) {
        if (e.name == v) return e;
      }
    }
    return fallback;
  }

  static ReaderSettings _fromMap(Map<String, dynamic> m) {
    return ReaderSettings(
      theme: _enum(m['theme'], ReaderTheme.values, ReaderTheme.system),
      mode: _enum(m['mode'], ReaderMode.values, ReaderMode.paginated),
      fontSize: (m['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (m['lineHeight'] as num?)?.toDouble() ?? 1.6,
      margin: (m['margin'] as num?)?.toDouble() ?? 20.0,
      font: _enum(m['font'], ReaderFont.values, ReaderFont.literata),
      paragraphSpacing: (m['paragraphSpacing'] as num?)?.toDouble() ?? 20.0,
      letterSpacing: (m['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      wordSpacing: (m['wordSpacing'] as num?)?.toDouble() ?? 0.0,
      fontWeightDelta: (m['fontWeightDelta'] as num?)?.toDouble() ?? 0.0,
      textAlign: _enum(m['textAlign'], ReaderTextAlign.values, ReaderTextAlign.justify),
      autoThemeMode: _enum(m['autoThemeMode'], AutoThemeMode.values, AutoThemeMode.off),
      customDayHour: (m['customDayHour'] as num?)?.toInt() ?? 7,
      customNightHour: (m['customNightHour'] as num?)?.toInt() ?? 20,
      brightness: (m['brightness'] as num?)?.toDouble() ?? 1.0,
      warmth: (m['warmth'] as num?)?.toDouble() ?? 0.0,
      keepScreenAwake: m['keepScreenAwake'] as bool? ?? true,
      autoHideDelay: (m['autoHideDelay'] as num?)?.toInt() ?? 3,
      paragraphFirstLineIndent: (m['paragraphFirstLineIndent'] as num?)?.toDouble() ?? 0.0,
      hyphenation: m['hyphenation'] as bool? ?? true,
      oldStyleFigures: m['oldStyleFigures'] as bool? ?? false,
      smallCaps: m['smallCaps'] as bool? ?? false,
      rsvpWpm: (m['rsvpWpm'] as num?)?.toInt() ?? 300,
      ignoreBookAlignment: m['ignoreBookAlignment'] as bool? ?? false,
      ignoreBookIndent: m['ignoreBookIndent'] as bool? ?? false,
      pageTurnAnimation: _enum(
        m['pageTurnAnimation'],
        PageTurnAnimation.values,
        PageTurnAnimation.slide,
      ),
      textDirection: _enum(
        m['textDirection'],
        ReaderTextDirection.values,
        ReaderTextDirection.auto,
      ),
      readerWidth: (m['readerWidth'] as num?)?.toDouble() ?? 820.0,
      verticalSwipeBrightness: m['verticalSwipeBrightness'] as bool? ?? true,
      customCss: m['customCss'] as String? ?? '',
    );
  }
}

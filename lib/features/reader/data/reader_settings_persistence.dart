import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reader.dart';

class ReaderSettingsPersistence {
  static const _key = 'reader_settings';

  static Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return const ReaderSettings();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return ReaderSettings(
        theme: ReaderTheme.values.firstWhere(
          (e) => e.name == map['theme'],
          orElse: () => ReaderTheme.dark,
        ),
        mode: ReaderMode.values.firstWhere(
          (e) => e.name == map['mode'],
          orElse: () => ReaderMode.continuous,
        ),
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.55,
        margin: (map['margin'] as num?)?.toDouble() ?? 16.0,
        font: ReaderFont.values.firstWhere(
          (e) => e.name == map['font'],
          orElse: () => ReaderFont.sourceSerif,
        ),
        paragraphSpacing: (map['paragraphSpacing'] as num?)?.toDouble() ?? 8.0,
        letterSpacing: (map['letterSpacing'] as num?)?.toDouble() ?? 0.0,
        textAlign: ReaderTextAlign.values.firstWhere(
          (e) => e.name == map['textAlign'],
          orElse: () => ReaderTextAlign.justify,
        ),
        autoThemeMode: AutoThemeMode.values.firstWhere(
          (e) => e.name == map['autoThemeMode'],
          orElse: () => AutoThemeMode.off,
        ),
        customDayHour: (map['customDayHour'] as num?)?.toInt() ?? 7,
        customNightHour: (map['customNightHour'] as num?)?.toInt() ?? 20,
      );
    } on Object catch (_) {
      return const ReaderSettings();
    }
  }

  static Future<void> save(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'theme': settings.theme.name,
        'mode': settings.mode.name,
        'fontSize': settings.fontSize,
        'lineHeight': settings.lineHeight,
        'margin': settings.margin,
        'font': settings.font.name,
        'paragraphSpacing': settings.paragraphSpacing,
        'letterSpacing': settings.letterSpacing,
        'textAlign': settings.textAlign.name,
        'autoThemeMode': settings.autoThemeMode.name,
        'customDayHour': settings.customDayHour,
        'customNightHour': settings.customNightHour,
      }),
    );
  }
}

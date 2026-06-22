import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

enum ContentSafetyLevel {
  standard('Стандартный', 'Показывать весь контент'),
  moderate('Умеренный', 'Скрывать откровенный контент'),
  strict('Строгий', 'Показывать только безопасный контент');

  const ContentSafetyLevel(this.displayName, this.description);
  final String displayName;
  final String description;
}

class ContentSafetyService {
  static const _key = 'content_safety_level';

  static SharedPreferencesWithCache? _prefs;

  static Future<SharedPreferencesWithCache> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_key},
      ),
    );
    return _prefs!;
  }

  static Future<ContentSafetyLevel> load() async {
    try {
      final prefs = await _getPrefs();
      final index = prefs.getInt(_key) ?? 0;
      final safeIndex = index.clamp(0, ContentSafetyLevel.values.length - 1);
      return ContentSafetyLevel.values[safeIndex];
    } on Object catch (e) {
      AppLogger().warning('Failed to load safety level: $e', name: 'ContentSafety', error: e);
      return ContentSafetyLevel.standard;
    }
  }

  static Future<void> save(ContentSafetyLevel level) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(_key, level.index);
    } on Object catch (e) {
      AppLogger().warning('Failed to save safety level: $e', name: 'ContentSafety', error: e);
    }
  }
}

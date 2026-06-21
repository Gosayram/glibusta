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

  static bool shouldFilter(ContentSafetyLevel level, List<String> tags) {
    if (level == ContentSafetyLevel.standard) return false;
    if (level == ContentSafetyLevel.strict) {
      return _unsafeTags.any((u) => tags.any((t) => t.toLowerCase().contains(u)));
    }
    return _explicitTags.any((e) => tags.any((t) => t.toLowerCase().contains(e)));
  }

  static bool shouldFilterTitle(ContentSafetyLevel level, String title) {
    if (level == ContentSafetyLevel.standard) return false;
    final lower = title.toLowerCase();
    if (level == ContentSafetyLevel.strict) {
      return _unsafeTags.any((u) => lower.contains(u));
    }
    return _explicitTags.any((e) => lower.contains(e));
  }

  static const _explicitTags = <String>[
    '18+',
    'adult',
    'nsfw',
    'erotic',
    'erotica',
  ];

  static const _unsafeTags = <String>[
    '18+',
    'adult',
    'nsfw',
    'erotic',
    'erotica',
    'violence',
    'gore',
    'horror',
  ];
}

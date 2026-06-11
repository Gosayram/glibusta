import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<ContentSafetyLevel> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_key) ?? 0;
      final safeIndex = index.clamp(0, ContentSafetyLevel.values.length - 1);
      return ContentSafetyLevel.values[safeIndex];
    } on Object catch (e, st) {
      developer.log(
        'Failed to load safety level',
        name: 'ContentSafetyService',
        error: e,
        stackTrace: st,
      );
      return ContentSafetyLevel.standard;
    }
  }

  static Future<void> save(ContentSafetyLevel level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, level.index);
    } on Object catch (e, st) {
      developer.log(
        'Failed to save safety level',
        name: 'ContentSafetyService',
        error: e,
        stackTrace: st,
      );
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

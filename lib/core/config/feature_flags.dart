import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.name,
    required this.description,
    this.defaultValue = false,
    this.isExperimental = false,
  });

  final String key;
  final String name;
  final String description;
  final bool defaultValue;
  final bool isExperimental;
}

class FeatureFlagDefs {
  static const newReaderEngine = FeatureFlag(
    key: 'new_reader_engine',
    name: 'Новый движок читалки',
    description: 'Экспериментальный рендерер текста с поддержкой новых фич',
    isExperimental: true,
  );

  static const newCardDesign = FeatureFlag(
    key: 'new_card_design',
    name: 'Новый дизайн карточек',
    description: 'Обновлённый визуал карточек книг в каталоге',
  );

  static const experimentalPdf = FeatureFlag(
    key: 'experimental_pdf',
    name: 'Экспериментальный PDF',
    description: 'Встроенный PDF-ридер вместо внешнего приложения',
    isExperimental: true,
  );

  static const newThemes = FeatureFlag(
    key: 'new_themes',
    name: 'Новые темы',
    description: 'Дополнительные темы оформления',
  );

  static const backgroundIndexer = FeatureFlag(
    key: 'background_indexer',
    name: 'Фоновая индексация',
    description: 'Автоматическая индексация библиотеки в фоне',
    isExperimental: true,
  );

  static const offlineMode = FeatureFlag(
    key: 'offline_mode',
    name: 'Оффлайн режим',
    description: 'Улучшенная работа без интернета',
  );

  static const advancedCache = FeatureFlag(
    key: 'advanced_cache',
    name: 'Продвинутый кэш',
    description: 'Умная политика кэширования обложек и метаданных',
  );

  static List<FeatureFlag> get all => [
    newReaderEngine,
    newCardDesign,
    experimentalPdf,
    newThemes,
    backgroundIndexer,
    offlineMode,
    advancedCache,
  ];
}

class FeatureFlagService {
  FeatureFlagService(this._prefs);
  final SharedPreferences _prefs;
  static const _prefix = 'ff_';

  bool isEnabled(FeatureFlag flag) {
    return _prefs.getBool('$_prefix${flag.key}') ?? flag.defaultValue;
  }

  Future<void> setEnabled(FeatureFlag flag, bool value) async {
    await _prefs.setBool('$_prefix${flag.key}', value);
  }

  Future<void> toggle(FeatureFlag flag) async {
    await setEnabled(flag, !isEnabled(flag));
  }

  Map<FeatureFlag, bool> getAllFlags() {
    return {for (final f in FeatureFlagDefs.all) f: isEnabled(f)};
  }

  Future<void> resetAll() async {
    for (final flag in FeatureFlagDefs.all) {
      await _prefs.remove('$_prefix${flag.key}');
    }
  }
}

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  throw StateError(
    'featureFlagServiceProvider must be overridden at startup with a SharedPreferences-backed instance.',
  );
});

final featureFlagsProvider = Provider<Map<FeatureFlag, bool>>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.getAllFlags();
});

final isFlagEnabledProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(flag);
});

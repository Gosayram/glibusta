import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../domain/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsServiceImpl(ref);
});

class SettingsServiceImpl implements SettingsService {
  final Ref _ref;

  SettingsServiceImpl(this._ref);

  @override
  Future<String> getBaseUrl() async {
    return _ref.read(appSettingsProvider).baseUrl;
  }

  @override
  Future<void> setBaseUrl(String url) async {
    final current = _ref.read(appSettingsProvider);
    _ref.read(appSettingsProvider.notifier).state = current.copyWith(baseUrl: url);
  }

  @override
  Future<List<String>> getMirrors() async {
    return _ref.read(appSettingsProvider).mirrors;
  }

  @override
  Future<void> setMirrors(List<String> mirrors) async {
    final current = _ref.read(appSettingsProvider);
    _ref.read(appSettingsProvider.notifier).state = current.copyWith(mirrors: mirrors);
  }

  @override
  Future<int> getMaxConcurrentDownloads() async {
    return _ref.read(appSettingsProvider).maxConcurrentDownloads;
  }

  @override
  Future<void> setMaxConcurrentDownloads(int count) async {
    final current = _ref.read(appSettingsProvider);
    _ref.read(appSettingsProvider.notifier).state = current.copyWith(maxConcurrentDownloads: count);
  }
}

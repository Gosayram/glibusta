import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref);
});

class SettingsService {
  final Ref ref;

  SettingsService(this.ref);

  Future<void> setBaseUrl(String url) async {
    // Implementation will use SharedPreferences or Drift
  }

  Future<void> setMirrors(List<String> mirrors) async {
    // Implementation will use SharedPreferences or Drift
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    // Implementation will use SharedPreferences or Drift
  }
}

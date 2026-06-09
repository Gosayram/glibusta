abstract class SettingsService {
  Future<String> getBaseUrl();
  Future<void> setBaseUrl(String url);

  Future<List<String>> getMirrors();
  Future<void> setMirrors(List<String> mirrors);

  Future<int> getMaxConcurrentDownloads();
  Future<void> setMaxConcurrentDownloads(int count);
}

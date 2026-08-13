import 'external_book_file.dart';

abstract interface class StorageBridge {
  Future<String?> pickFolder();
  Future<int> countBooks(String folderUri);
  Future<List<ExternalBookFile>> scanBooks(String folderUri);

  /// Copies a SAF URI into the app cache without exceeding [maxBytes], when
  /// supplied. Native implementations must enforce the bound while streaming,
  /// because a provider can omit or lie about its advertised document size.
  Future<String?> copyToCache(String fileUri, {int? maxBytes});
  Future<List<String>> getPersistedUris();
  Future<bool> forgetUri(String uri);
}

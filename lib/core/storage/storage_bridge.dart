import 'external_book_file.dart';

abstract interface class StorageBridge {
  Future<String?> pickFolder();
  Future<int> countBooks(String folderUri);
  Future<List<ExternalBookFile>> scanBooks(String folderUri);
  Future<String?> copyToCache(String fileUri);
  Future<List<String>> getPersistedUris();
  Future<bool> forgetUri(String uri);
}

import 'dart:typed_data';

import 'external_book_file.dart';

abstract interface class StorageBridge {
  Future<String?> pickFolder();
  Future<List<ExternalBookFile>> scanBooks(String folderUri);
  Future<Uint8List> readFile(String fileUri);
  Future<List<String>> getPersistedUris();
}

import '../storage/external_book_file.dart';
import '../storage/storage_bridge.dart';

final class FolderScanService {
  FolderScanService(this._bridge);

  final StorageBridge _bridge;
  static const supportedBookExtensions = [
    'epub',
    'fb2',
    'zip',
    'txt',
    'rtf',
    'mobi',
    'azw',
    'azw3',
    'prc',
    'djvu',
    'djv',
  ];

  Future<List<ExternalBookFile>> scan(String folderUri) async {
    final files = await _bridge.scanBooks(folderUri);
    return files.where((f) => supportedBookExtensions.contains(f.extension)).toList();
  }

  Future<List<ExternalBookFile>> scanWithFormats(
    String folderUri, {
    List<String> formats = supportedBookExtensions,
  }) async {
    final files = await _bridge.scanBooks(folderUri);
    return files.where((f) => formats.contains(f.extension)).toList();
  }
}

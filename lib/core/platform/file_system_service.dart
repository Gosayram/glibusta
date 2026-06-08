import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

class FileSystemService {
  final FileSystem _fs = const LocalFileSystem();

  Future<Directory> getLibraryRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.normalize(p.join(docsDir.path, 'Glibusta', 'books'));
    final dir = _fs.directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final path = p.normalize(p.join(tempDir.path, 'glibusta_temp'));
    final dir = _fs.directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> getBookFile(String bookId, {String ext = 'fb2'}) async {
    final libraryRoot = await getLibraryRoot();
    final sanitizedId = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return libraryRoot.childFile('book_${sanitizedId}.$ext');
  }

  bool isWithinLibrary(String targetPath) {
    try {
      final normalized = p.normalize(targetPath);
      // Synchronously check by comparing path prefixes
      // In production, this should use async getLibraryRoot()
      return normalized.contains('Glibusta${p.separator}books');
    } catch (_) {
      return false;
    }
  }

  Future<bool> isWithinLibraryAsync(String targetPath) async {
    try {
      final libraryRoot = await getLibraryRoot();
      final normalized = p.normalize(targetPath);
      final libraryPath = p.normalize(libraryRoot.path);
      return p.isWithin(libraryPath, normalized);
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureDirectories() async {
    await getLibraryRoot();
    await getTempDirectory();
  }
}

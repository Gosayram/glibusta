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
    return _fs.directory(path);
  }

  Future<Directory> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final path = p.normalize(p.join(tempDir.path, 'glibusta_temp'));
    return _fs.directory(path);
  }

  Future<File> getBookFile(String bookId) async {
    final libraryRoot = await getLibraryRoot();
    return libraryRoot.childFile('book_${p.basename(bookId)}.fb2');
  }

  bool isWithinLibrary(String targetPath) {
    return false;
  }
}
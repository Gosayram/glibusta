import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

class FileSystemService {
  final FileSystem _fs = const LocalFileSystem();

  Future<Directory> getLibraryRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return _fs.directory(p.join(docsDir.path, 'Glibusta', 'books'));
  }

  Future<Directory> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    return _fs.directory(p.join(tempDir.path, 'glibusta_temp'));
  }

  Future<File> getBookFile(String bookId) async {
    final libraryRoot = await getLibraryRoot();
    return libraryRoot.childFile('book_$bookId.fb2');
  }
}
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/failures.dart';

final class BookFileStorage {
  Future<File> copyToLibrary(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const BookOpenFailure('Файл не найден');
    }

    final fileName = p.basename(sourcePath);
    final target = File(p.join(booksDir.path, fileName));

    if (await target.exists()) {
      return target;
    }

    return source.copy(target.path);
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/book.dart';

abstract interface class AppFileStorage {
  Future<File> bookFile(String bookId, BookFormat format);
  Future<File> coverFile(String bookId);
  Future<Directory> tempDir();
  Future<Directory> booksDir();
  Future<Directory> coversDir();
}

class AppFileStorageImpl implements AppFileStorage {
  @override
  Future<Directory> booksDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(dir.path, 'glibusta', 'books'));
    await booksDir.create(recursive: true);
    return booksDir;
  }

  @override
  Future<Directory> coversDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(dir.path, 'glibusta', 'covers'));
    await coversDir.create(recursive: true);
    return coversDir;
  }

  @override
  Future<File> bookFile(String bookId, BookFormat format) async {
    final dir = await booksDir();
    return File(p.join(dir.path, '$bookId.${format.name}'));
  }

  @override
  Future<File> coverFile(String bookId) async {
    final dir = await coversDir();
    return File(p.join(dir.path, '$bookId.jpg'));
  }

  @override
  Future<Directory> tempDir() async {
    final dir = await getTemporaryDirectory();
    final tempDir = Directory(p.join(dir.path, 'glibusta'));
    await tempDir.create(recursive: true);
    return tempDir;
  }
}

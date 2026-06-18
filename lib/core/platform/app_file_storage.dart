import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/book.dart';

final appFileStorageProvider = Provider<AppFileStorage>((ref) {
  return AppFileStorageImpl();
});

abstract interface class AppFileStorage {
  Future<File> bookFile(String bookId, BookFormat format);
  Future<File> coverFile(String bookId);
  Future<Directory> tempDir();
  Future<Directory> booksDir();
  Future<Directory> coversDir();
  Future<Directory> cacheDir();
  Future<Directory> catalogCoversDir();
}

String sanitizeId(String id) {
  var sanitized = id.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  while (sanitized.startsWith('.')) {
    sanitized = sanitized.substring(1);
  }
  sanitized = sanitized.trim();
  if (sanitized.isEmpty) sanitized = 'unnamed';
  if (sanitized.length > 200) sanitized = sanitized.substring(0, 200);
  return sanitized;
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
    return File(p.join(dir.path, '${sanitizeId(bookId)}.${format.name}'));
  }

  @override
  Future<File> coverFile(String bookId) async {
    final dir = await coversDir();
    return File(p.join(dir.path, '${sanitizeId(bookId)}.jpg'));
  }

  @override
  Future<Directory> tempDir() async {
    final dir = await getTemporaryDirectory();
    final tempDir = Directory(p.join(dir.path, 'glibusta'));
    await tempDir.create(recursive: true);
    return tempDir;
  }

  @override
  Future<Directory> cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(dir.path, 'glibusta', 'cache'));
    await cacheDir.create(recursive: true);
    return cacheDir;
  }

  @override
  Future<Directory> catalogCoversDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final catalogDir = Directory(p.join(dir.path, 'glibusta', 'catalog_covers'));
    await catalogDir.create(recursive: true);
    return catalogDir;
  }
}

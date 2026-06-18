import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../platform/app_file_storage.dart';

class StorageCategory {
  const StorageCategory({
    required this.name,
    required this.icon,
    required this.sizeBytes,
  });

  final String name;
  final String icon;
  final int sizeBytes;

  String get sizeHuman => formatBytes(sizeBytes);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class StorageInfoModel {
  const StorageInfoModel({required this.categories});

  final List<StorageCategory> categories;

  int get totalBytes => categories.fold(0, (sum, c) => sum + c.sizeBytes);
  String get totalHuman => formatBytes(totalBytes);
}

Future<StorageInfoModel> computeStorageInfo(AppDatabase db) async {
  final storage = AppFileStorageImpl();

  final dbSize = await _dirSize(p.dirname(await _dbPath(db)));
  final booksSize = await _dirSize((await storage.booksDir()).path);
  final coversSize = await _dirSize((await storage.coversDir()).path);
  final catalogCoversSize = await _dirSize((await storage.catalogCoversDir()).path);
  final cacheSize = await _dirSize((await storage.cacheDir()).path);
  final tempSize = await _dirSize((await storage.tempDir()).path);

  return StorageInfoModel(
    categories: [
      StorageCategory(name: 'База данных', icon: 'database', sizeBytes: dbSize),
      StorageCategory(name: 'Книги', icon: 'book', sizeBytes: booksSize),
      StorageCategory(name: 'Обложки', icon: 'image', sizeBytes: coversSize),
      StorageCategory(name: 'Обложки каталога', icon: 'catalog', sizeBytes: catalogCoversSize),
      StorageCategory(name: 'Кеш', icon: 'cache', sizeBytes: cacheSize),
      StorageCategory(name: 'Временные', icon: 'temp', sizeBytes: tempSize),
    ],
  );
}

Future<int> _dirSize(String path) async {
  int total = 0;
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        total += stat.size;
      }
    }
  } on Object catch (_) {}
  return total;
}

Future<String> _dbPath(AppDatabase db) async {
  final dir = await AppFileStorageImpl().dbDir();
  return p.join(dir.path, 'glibusta.sqlite');
}

final storageInfoProvider = FutureProvider<StorageInfoModel>((ref) {
  final db = ref.watch(databaseProvider);
  return computeStorageInfo(db);
});

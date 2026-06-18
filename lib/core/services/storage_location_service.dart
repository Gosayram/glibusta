import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomStorageLocation {
  const CustomStorageLocation({
    required this.path,
    required this.type,
  });

  final String path;
  final StorageLocationType type;
}

enum StorageLocationType { default_, custom }

class StorageLocationService {
  StorageLocationService(this._prefs);

  final SharedPreferences _prefs;
  static const _customPathKey = 'custom_storage_path';

  Future<Directory> getBooksDirectory() async {
    final customPath = _prefs.getString(_customPathKey);
    if (customPath != null) {
      final dir = Directory('$customPath/books');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/books');
  }

  Future<Directory> getCacheDirectory() async {
    final customPath = _prefs.getString(_customPathKey);
    if (customPath != null) {
      final dir = Directory('$customPath/cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationSupportDirectory();
    return Directory('${appDir.path}/cache');
  }

  Future<Directory> getDatabaseDirectory() async {
    final customPath = _prefs.getString(_customPathKey);
    if (customPath != null) {
      final dir = Directory('$customPath/database');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/database');
  }

  Future<void> setCustomPath(String path) async {
    await _prefs.setString(_customPathKey, path);
  }

  String? getCustomPath() {
    return _prefs.getString(_customPathKey);
  }

  Future<void> clearCustomPath() async {
    await _prefs.remove(_customPathKey);
  }

  bool get isCustomLocation => _prefs.getString(_customPathKey) != null;

  Future<int> getStorageSize() async {
    int total = 0;
    final dirs = [
      await getBooksDirectory(),
      await getCacheDirectory(),
      await getDatabaseDirectory(),
    ];

    for (final dir in dirs) {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    }

    return total;
  }
}

final storageLocationServiceProvider = Provider<StorageLocationService>((ref) {
  throw UnimplementedError('storageLocationServiceProvider must be overridden at startup.');
});

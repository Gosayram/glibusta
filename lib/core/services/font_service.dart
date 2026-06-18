import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class FontModel {
  const FontModel({
    required this.name,
    required this.fileName,
    this.family,
    this.weight = FontWeight.normal,
    this.style = FontStyle.normal,
    this.isDownloaded = false,
    this.downloadUrl,
    this.fileSize = 0,
  });

  final String name;
  final String fileName;
  final String? family;
  final FontWeight weight;
  final FontStyle style;
  final bool isDownloaded;
  final String? downloadUrl;
  final int fileSize;

  String get displayName => name;

  Map<String, dynamic> toJson() => {
    'name': name,
    'fileName': fileName,
    'family': family,
    'weight': weight.value,
    'style': style.index,
    'isDownloaded': isDownloaded,
    'downloadUrl': downloadUrl,
    'fileSize': fileSize,
  };

  factory FontModel.fromJson(Map<String, dynamic> json) => FontModel(
    name: json['name'] as String,
    fileName: json['fileName'] as String,
    family: json['family'] as String?,
    weight: FontWeight.values[json['weight'] as int? ?? 3],
    style: FontStyle.values[json['style'] as int? ?? 0],
    isDownloaded: json['isDownloaded'] as bool? ?? false,
    downloadUrl: json['downloadUrl'] as String?,
    fileSize: json['fileSize'] as int? ?? 0,
  );
}

class FontCacheService {
  FontCacheService(this._directory);

  final Directory _directory;

  Future<Directory> get _fontsDir async {
    final dir = Directory('${_directory.path}/fonts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<FontModel>> getDownloadedFonts() async {
    final dir = await _fontsDir;
    final files = await dir.list().where((e) => e is File).toList();
    final fonts = <FontModel>[];

    for (final file in files) {
      if (file.path.endsWith('.ttf') || file.path.endsWith('.otf')) {
        final fileName = file.path.split('/').last;
        fonts.add(
          FontModel(
            name: fileName.split('.').first,
            fileName: fileName,
            isDownloaded: true,
            fileSize: await (file as File).length(),
          ),
        );
      }
    }

    return fonts;
  }

  Future<File> getFontFile(String fileName) async {
    final dir = await _fontsDir;
    return File('${dir.path}/$fileName');
  }

  Future<void> deleteFont(String fileName) async {
    final file = await getFontFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<int> getCacheSize() async {
    final dir = await _fontsDir;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    final dir = await _fontsDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

final fontCacheServiceProvider = FutureProvider<FontCacheService>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return FontCacheService(dir);
});

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path_provider/path_provider.dart';

part 'font_service.freezed.dart';
part 'font_service.g.dart';

@freezed
abstract class FontModel with _$FontModel {
  const factory FontModel({
    required String name,
    required String fileName,
    String? family,
    @JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson)
    @Default(FontWeight.normal)
    FontWeight weight,
    @JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson)
    @Default(FontStyle.normal)
    FontStyle style,
    @Default(false) bool isDownloaded,
    String? downloadUrl,
    @Default(0) int fileSize,
  }) = _FontModel;

  const FontModel._();

  String get displayName => name;

  factory FontModel.fromJson(Map<String, dynamic> json) => _$FontModelFromJson(json);
}

int _fontWeightToJson(FontWeight weight) => weight.value;

FontWeight _fontWeightFromJson(Object? value) {
  if (value is int) {
    // Value form (e.g. 400 for normal).
    if (value >= 100) {
      final index = (value ~/ 100) - 1;
      if (index >= 0 && index < FontWeight.values.length) {
        return FontWeight.values[index];
      }
    }
    // Legacy index form (0..8).
    if (value >= 0 && value < FontWeight.values.length) {
      return FontWeight.values[value];
    }
  }
  return FontWeight.normal;
}

int _fontStyleToJson(FontStyle style) => style.index;

FontStyle _fontStyleFromJson(int index) =>
    index == FontStyle.italic.index ? FontStyle.italic : FontStyle.normal;

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

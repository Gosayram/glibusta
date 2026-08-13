import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EpubFontLoader {
  static final Set<String> _loadedPaths = {};

  static Future<Map<String, Uint8List>> loadFonts({
    required String epubPath,
    required Map<String, dynamic> fontMap,
  }) async {
    if (fontMap.isEmpty) return const {};

    try {
      final file = File(epubPath);
      if (!file.existsSync()) return const {};

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fontBytes = <String, Uint8List>{};

      for (final entry in fontMap.entries) {
        final family = entry.key;
        final srcPath = entry.value.toString();

        final normalizedPath = _normalizePath(srcPath);
        final archiveFile = _findInArchive(archive, normalizedPath);

        if (archiveFile != null) {
          final fontData = archiveFile.content as List<int>;
          fontBytes[family] = Uint8List.fromList(fontData);
        }
      }

      if (fontBytes.isEmpty) return const {};

      for (final entry in fontBytes.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          Future.value(ByteData.sublistView(entry.value)),
        );
        await loader.load();
      }

      _loadedPaths.add(epubPath);
      return fontBytes;
    } on Object catch (e) {
      debugPrint('CRT-1.14: Font extraction failed: $e');
      return const {};
    }
  }

  static bool isLoaded(String epubPath) => _loadedPaths.contains(epubPath);

  static String _normalizePath(String path) {
    var p = path.replaceAll(r'\', '/');
    if (p.startsWith('/')) p = p.substring(1);
    return p;
  }

  static ArchiveFile? _findInArchive(Archive archive, String path) {
    for (final file in archive) {
      if (file.name == path) return file;
    }
    final lower = path.toLowerCase();
    for (final file in archive) {
      if (file.name.toLowerCase() == lower) return file;
    }
    final baseName = path.split('/').last.toLowerCase();
    for (final file in archive) {
      if (file.name.split('/').last.toLowerCase() == baseName) return file;
    }
    return null;
  }
}

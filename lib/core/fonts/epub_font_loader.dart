import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// CRT-1.14: Extract and register @font-face fonts from EPUB files.
/// Reads the EPUB ZIP, extracts embedded font files, registers with FontLoader.
class EpubFontLoader {
  /// Extract fonts from an EPUB file and register them.
  /// [fontMap] is the metadata.fonts map from NormalizedBook (family → relative path).
  static Future<void> loadFonts({
    required String epubPath,
    required Map<String, dynamic> fontMap,
  }) async {
    if (fontMap.isEmpty) return;

    try {
      final file = File(epubPath);
      if (!file.existsSync()) return;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final loader = FontLoader('epub_embedded_fonts');

      var fontCount = 0;
      for (final entry in fontMap.entries) {
        final family = entry.key;
        final srcPath = entry.value.toString();

        // Normalize path (EPUB paths can have different prefixes)
        final normalizedPath = _normalizePath(srcPath);
        final archiveFile = _findInArchive(archive, normalizedPath);

        if (archiveFile != null) {
          final fontData = archiveFile.content as List<int>;
          loader.addFont(
            Future.value(ByteData.sublistView(Uint8List.fromList(fontData))),
          );
          debugPrint('CRT-1.14: Loaded font "$family" from $srcPath');
          fontCount++;
        } else {
          debugPrint('CRT-1.14: Font file not found: $srcPath');
        }
      }

      if (fontCount > 0) {
        await loader.load();
        debugPrint('CRT-1.14: Registered $fontCount embedded fonts');
      }
    } on Object catch (e) {
      debugPrint('CRT-1.14: Font extraction failed: $e');
    }
  }

  /// Normalize EPUB path — remove leading slashes, handle OEBPS/ prefix.
  static String _normalizePath(String path) {
    var p = path.replaceAll(r'\', '/');
    if (p.startsWith('/')) p = p.substring(1);
    return p;
  }

  /// Find a file in the ZIP archive by path (case-insensitive).
  static ArchiveFile? _findInArchive(Archive archive, String path) {
    // Exact match
    for (final file in archive) {
      if (file.name == path) return file;
    }
    // Case-insensitive match
    final lower = path.toLowerCase();
    for (final file in archive) {
      if (file.name.toLowerCase() == lower) return file;
    }
    // Match by filename only (ignoring directory)
    final baseName = path.split('/').last.toLowerCase();
    for (final file in archive) {
      if (file.name.split('/').last.toLowerCase() == baseName) return file;
    }
    return null;
  }
}

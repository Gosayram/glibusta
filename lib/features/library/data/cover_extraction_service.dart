import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

import '../../../core/platform/app_file_storage.dart';
import '../../reader/data/parsers/format_detector.dart';

final coverExtractionServiceProvider = Provider<CoverExtractionService>((ref) {
  return CoverExtractionService(ref.watch(appFileStorageProvider));
});

class CoverExtractionService {
  final AppFileStorage _storage;

  CoverExtractionService(this._storage);

  /// Extract cover from book file and save normalized to covers dir.
  /// [coverBytes] can be provided by the parser (e.g. MOBI) to skip
  /// redundant extraction from the file.
  Future<String?> extractAndSaveCover({
    required String bookId,
    required String filePath,
    required String format,
    Uint8List? coverBytes,
  }) async {
    try {
      final Uint8List? extracted;
      if (coverBytes != null) {
        extracted = coverBytes;
      } else {
        final fileBytes = await File(filePath).readAsBytes();
        final fmt = formatFromDbString(format);
        extracted = switch (fmt) {
          BookFormat.epub => _extractEpubCover(fileBytes),
          BookFormat.fb2 => _extractFb2Cover(fileBytes),
          _ => null,
        };
      }
      final bytes = extracted;

      if (bytes == null || bytes.isEmpty) return null;

      return await _saveNormalizedCover(
        bookId: bookId,
        coverBytes: bytes,
      );
    } on Object catch (_) {
      return null;
    }
  }

  /// Extract cover bytes from EPUB file.
  Uint8List? _extractEpubCover(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find cover from metadata
      final opfFile = _findOpfFile(archive);
      if (opfFile == null) return null;

      final opfContent = String.fromCharCodes(opfFile.content as List<int>);
      final doc = XmlDocument.parse(opfContent);

      // Find cover image ID from metadata
      final coverId = _findCoverId(doc);
      if (coverId == null) return null;

      // Find cover href from manifest
      final coverHref = _findManifestHref(doc, coverId);
      if (coverHref == null) return null;

      // Get cover bytes from archive
      final coverFile = _findArchiveFile(archive, coverHref);
      if (coverFile == null) return null;

      return Uint8List.fromList(coverFile.content as List<int>);
    } on Object catch (_) {
      return null;
    }
  }

  /// Extract cover bytes from FB2 file.
  Uint8List? _extractFb2Cover(Uint8List bytes) {
    try {
      final text = String.fromCharCodes(bytes);
      final doc = XmlDocument.parse(text);

      // Find coverpage > image href
      final coverHref = doc
          .findAllElements('coverpage')
          .expand((e) => e.findAllElements('image'))
          .map((e) => e.getAttribute('l:href') ?? e.getAttribute('href'))
          .whereType<String>()
          .firstOrNull;

      if (coverHref == null) return null;

      final imageId = coverHref.replaceFirst('#', '');
      final binary = doc
          .findAllElements('binary')
          .firstWhereOrNull(
            (XmlNode e) => e.getAttribute('id') == imageId,
          );

      if (binary == null) return null;

      final base64Data = binary.innerText.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(base64Data);
    } on Object catch (_) {
      return null;
    }
  }

  ArchiveFile? _findOpfFile(Archive archive) {
    // Try META-INF/container.xml first
    final containerFile = archive.files.firstWhereOrNull(
      (ArchiveFile f) => f.name == 'META-INF/container.xml',
    );
    if (containerFile != null) {
      final containerDoc = XmlDocument.parse(
        String.fromCharCodes(containerFile.content as List<int>),
      );
      final rootFilePath = containerDoc
          .findAllElements('rootfile')
          .firstOrNull
          ?.getAttribute('full-path');
      if (rootFilePath != null) {
        return archive.files.firstWhereOrNull(
          (ArchiveFile f) => f.name == rootFilePath,
        );
      }
    }
    // Fallback: find any .opf file
    return archive.files.firstWhereOrNull(
      (ArchiveFile f) => f.name.endsWith('.opf'),
    );
  }

  String? _findCoverId(XmlDocument doc) {
    // Try <meta name="cover" content="cover-image"/>
    return doc
        .findAllElements('meta')
        .where((XmlElement e) => e.getAttribute('name') == 'cover')
        .map((XmlElement e) => e.getAttribute('content'))
        .whereType<String>()
        .firstOrNull;
  }

  String? _findManifestHref(XmlDocument doc, String id) {
    return doc
        .findAllElements('item')
        .where((XmlElement e) => e.getAttribute('id') == id)
        .map((XmlElement e) => e.getAttribute('href'))
        .whereType<String>()
        .firstOrNull;
  }

  ArchiveFile? _findArchiveFile(Archive archive, String href) {
    final normalized = href.startsWith('/') ? href.substring(1) : href;
    return archive.files.firstWhereOrNull(
      (ArchiveFile f) => f.name == normalized || f.name.endsWith('/$normalized'),
    );
  }

  Future<String?> _saveNormalizedCover({
    required String bookId,
    required Uint8List coverBytes,
  }) async {
    final decoded = img.decodeImage(coverBytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: 320,
      maintainAspect: true,
    );

    final jpg = img.encodeJpg(resized, quality: 82);
    final coversDir = await _storage.coversDir();
    final file = File('${coversDir.path}/$bookId.jpg');
    await file.writeAsBytes(jpg, flush: true);
    return file.path;
  }
}

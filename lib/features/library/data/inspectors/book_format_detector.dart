import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../reader/data/parsers/format_detector.dart';

final class BookFormatDetector {
  BookFormat detect({required String path, required List<int> bytes}) {
    final byExtension = detectBookFormat(path);
    if (byExtension != BookFormat.unknown) return byExtension;
    return _detectByMagicBytes(bytes);
  }

  BookFormat detectFromBytes({required List<int> bytes, String? path}) {
    if (path != null) {
      final byExtension = detectBookFormat(path);
      if (byExtension != BookFormat.unknown) return byExtension;
    }
    return _detectByMagicBytes(bytes);
  }

  BookFormat _detectByMagicBytes(List<int> bytes) {
    if (bytes.length < 4) return BookFormat.unknown;

    // ZIP-based formats: check if it's a valid ZIP first
    if (_isZipArchive(bytes)) {
      return _detectZipContent(bytes);
    }

    // PDF: %PDF
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return BookFormat.pdf;
    }

    // FB2 (non-zip): starts with <?xml or <FictionBook
    if (_isFb2Xml(bytes)) return BookFormat.fb2;

    return BookFormat.unknown;
  }

  bool _isZipArchive(List<int> bytes) {
    // ZIP local file header signature: 0x04034b50
    return bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;
  }

  BookFormat _detectZipContent(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(Uint8List.fromList(bytes));
      final fileNames = archive.files.map((f) => f.name).toList();

      // EPUB: has META-INF/container.xml
      if (fileNames.any((n) => n == 'META-INF/container.xml')) {
        return BookFormat.epub;
      }

      // DOCX: has [Content_Types].xml + word/document.xml
      if (fileNames.any((n) => n == '[Content_Types].xml') &&
          fileNames.any((n) => n.startsWith('word/'))) {
        return BookFormat.unknown; // DOCX recognized but no parser yet
      }

      // CBZ: majority of files are images
      final imageFiles = fileNames
          .where(
            (n) =>
                n.toLowerCase().endsWith('.jpg') ||
                n.toLowerCase().endsWith('.jpeg') ||
                n.toLowerCase().endsWith('.png') ||
                n.toLowerCase().endsWith('.webp') ||
                n.toLowerCase().endsWith('.gif'),
          )
          .length;
      if (imageFiles > 0 && imageFiles >= fileNames.length * 0.7) {
        return BookFormat.unknown; // CBZ recognized but no parser yet
      }

      // FB2.ZIP: contains .fb2 file
      if (fileNames.any((n) => n.toLowerCase().endsWith('.fb2'))) {
        return BookFormat.fb2;
      }

      // MOBI (some .mobi files are actually ZIP-based KF8)
      if (fileNames.any((n) => n == 'META-INF/encryption.xml')) {
        return BookFormat.unknown;
      }
    } on Object catch (_) {
      // Not a valid ZIP or too corrupt to read
    }

    return BookFormat.unknown;
  }

  bool _isFb2Xml(List<int> bytes) {
    // Check for XML declaration or FictionBook root element
    final sample = String.fromCharCodes(bytes.take(500)).toLowerCase();
    return sample.contains('<?xml') && sample.contains('fictionbook');
  }
}

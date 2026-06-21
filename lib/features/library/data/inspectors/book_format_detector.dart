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
      final fileNames = _readZipFileNames(bytes);
      if (fileNames.isEmpty) return BookFormat.unknown;

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

  /// Read file names from the ZIP central directory without decompressing.
  static List<String> _readZipFileNames(List<int> bytes) {
    if (bytes.length < 22) return []; // EOCD minimum size

    // Find EOCD (End of Central Directory) signature 0x06054b50
    final length = bytes.length;
    final searchLimit = length - 22;
    var eocdPos = -1;
    for (var i = searchLimit >= 0 ? searchLimit : 0; i >= 0; i--) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x05 &&
          bytes[i + 3] == 0x06) {
        eocdPos = i;
        break;
      }
    }
    if (eocdPos < 0) return [];

    final cdOffset =
        bytes[eocdPos + 16] |
        (bytes[eocdPos + 17] << 8) |
        (bytes[eocdPos + 18] << 16) |
        (bytes[eocdPos + 19] << 24);
    final cdSize =
        bytes[eocdPos + 12] |
        (bytes[eocdPos + 13] << 8) |
        (bytes[eocdPos + 14] << 16) |
        (bytes[eocdPos + 15] << 24);

    if (cdOffset + cdSize > length) return [];

    // Parse central directory entries (signature 0x02014b50)
    final names = <String>[];
    var pos = cdOffset;
    final cdEnd = cdOffset + cdSize;
    while (pos + 46 <= cdEnd && pos + 46 <= length) {
      if (bytes[pos] != 0x50 ||
          bytes[pos + 1] != 0x4B ||
          bytes[pos + 2] != 0x01 ||
          bytes[pos + 3] != 0x02) {
        break;
      }
      final fnameLen = bytes[pos + 28] | (bytes[pos + 29] << 8);
      final extraLen = bytes[pos + 30] | (bytes[pos + 31] << 8);
      final commentLen = bytes[pos + 32] | (bytes[pos + 33] << 8);
      if (pos + 46 + fnameLen > length) break;
      names.add(
        String.fromCharCodes(bytes.sublist(pos + 46, pos + 46 + fnameLen)),
      );
      pos += 46 + fnameLen + extraLen + commentLen;
    }
    return names;
  }

  bool _isFb2Xml(List<int> bytes) {
    // Check for XML declaration or FictionBook root element
    final sample = String.fromCharCodes(bytes.take(500)).toLowerCase();
    return sample.contains('<?xml') && sample.contains('fictionbook');
  }
}

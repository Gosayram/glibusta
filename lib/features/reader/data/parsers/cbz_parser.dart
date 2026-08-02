import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_charset/fl_charset.dart';
import 'package:xml/xml.dart';

import '../../../../core/encoding/encoding_utils.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/formats/archive_safety.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';
import 'rust_book_parser.dart';

final class CbzParser implements BookParser {
  static const int _maxComicInfoBytes = 1024 * 1024;

  @override
  bool supports(BookFormat format) => format == BookFormat.cbz;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      // Try Rust parser via temp file for best performance
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/glibusta_cbz_${DateTime.now().millisecondsSinceEpoch}.cbz',
      );
      try {
        await tempFile.writeAsBytes(bytes, flush: true);
        return await RustBookParser().parseFile(tempFile.path);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } on Object catch (_) {
      // Fall back to Dart parser if Rust fails
      return _parseDart(bytes, fileName: fileName);
    }
  }

  @override
  Future<NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  }) async {
    try {
      return await RustBookParser().parseFile(filePath);
    } on Object catch (e) {
      throw ParserFailure('Rust CBZ parser failed: $e');
    }
  }

  /// Dart fallback: parse CBZ from in-memory bytes.
  NormalizedBook _parseDart(Uint8List bytes, {String? fileName}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveSafety.validateZip(archive);
      final comicInfo = _readComicInfo(archive);
      final images = _sortedImageFiles(archive);
      if (images.isEmpty) {
        throw const ParserFailure('В архиве нет изображений');
      }
      final blocks = <ReaderBlock>[];
      for (var i = 0; i < images.length; i++) {
        final file = images[i];
        final ext = file.name.split('.').last.toLowerCase();
        final mimeType = _mimeTypeFor(ext);
        final contentBytes = ArchiveSafety.readEntryBytes(
          file,
          maxBytes: ArchiveSafety.maxSingleEntryBytes,
        );
        final dataUri = 'data:$mimeType;base64,${base64Encode(contentBytes)}';
        blocks.add(
          ReaderBlock(
            index: i,
            text: '',
            type: BlockType.image,
            imageUrl: dataUri,
          ),
        );
      }
      final metadata = <String, dynamic>{
        if (comicInfo?.series case final String series) 'series': series,
        if (comicInfo?.number case final String number) 'number': number,
      };
      return NormalizedBook(
        id: fileName ?? 'unknown.cbz',
        title: comicInfo?.title ?? _titleFromFileName(fileName),
        authors: comicInfo?.authors ?? const [],
        coverUrl: blocks.first.imageUrl,
        metadata: metadata.isEmpty ? null : metadata,
        chapters: [
          ReaderChapter(index: 0, title: 'Страницы', blocks: blocks),
        ],
      );
    } on ParserFailure {
      rethrow;
    } on Object catch (e) {
      throw ParserFailure('Ошибка разбора comic book: $e');
    }
  }

  List<ArchiveFile> _sortedImageFiles(Archive archive) {
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'jxl', 'avif'};
    final files = archive.files.where((f) {
      if (!f.isFile) return false;

      final pathParts = f.name.replaceAll(r'\', '/').split('/');
      final fileName = pathParts.last;
      // macOS adds AppleDouble resource forks to ZIP archives. Their names
      // look like image pages (for example `__MACOSX/._001.jpg`), but their
      // contents are metadata rather than decodable comic images.
      if (pathParts.contains('__MACOSX') || fileName.startsWith('._')) {
        return false;
      }

      final ext = fileName.split('.').last.toLowerCase();
      return imageExts.contains(ext);
    }).toList()..sort((a, b) => _naturalCompare(a.name, b.name));
    return files;
  }

  int _naturalCompare(String a, String b) {
    final aParts = _splitNatural(a);
    final bParts = _splitNatural(b);
    final len = min(aParts.length, bParts.length);
    for (var i = 0; i < len; i++) {
      final aVal = aParts[i];
      final bVal = bParts[i];
      if (aVal is int && bVal is int) {
        final cmp = aVal.compareTo(bVal);
        if (cmp != 0) return cmp;
      } else {
        final cmp = aVal.toString().compareTo(bVal.toString());
        if (cmp != 0) return cmp;
      }
    }
    return aParts.length.compareTo(bParts.length);
  }

  List<dynamic> _splitNatural(String s) {
    final parts = <dynamic>[];
    final buf = StringBuffer();
    var isDigit = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      final cIsDigit = RegExp(r'\d').hasMatch(c);
      if (i > 0 && cIsDigit != isDigit) {
        parts.add(isDigit ? int.parse(buf.toString()) : buf.toString());
        buf.clear();
      }
      buf.write(c);
      isDigit = cIsDigit;
    }
    if (buf.isNotEmpty) {
      parts.add(isDigit ? int.parse(buf.toString()) : buf.toString());
    }
    return parts;
  }

  String _mimeTypeFor(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
        return 'image/tiff';
      case 'jxl':
        return 'image/jxl';
      case 'avif':
        return 'image/avif';
      default:
        return 'image/jpeg';
    }
  }

  String _titleFromFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return 'Без названия';
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  _ComicInfo? _readComicInfo(Archive archive) {
    ArchiveFile? file;
    for (final entry in archive.files) {
      final name = entry.name.split('/').last.toLowerCase();
      if (entry.isFile && name == 'comicinfo.xml') {
        file = entry;
        break;
      }
    }
    if (file == null || file.size > _maxComicInfoBytes) return null;

    try {
      final document = XmlDocument.parse(
        _decodeComicInfoXml(
          ArchiveSafety.readEntryBytes(file, maxBytes: _maxComicInfoBytes),
        ),
      );
      String? value(String name) {
        final elements = document.descendants.whereType<XmlElement>().where(
          (element) => element.localName == name,
        );
        if (elements.isEmpty) return null;
        final text = elements.first.innerText.trim();
        return text.isEmpty ? null : text;
      }

      final writer = value('Writer');
      return _ComicInfo(
        title: value('Title'),
        authors: writer?.split(RegExp(r'\s*[,;]\s*')).where((author) => author.isNotEmpty).toList(),
        series: value('Series'),
        number: value('Number'),
      );
    } on XmlException {
      return null;
    }
  }

  String _decodeComicInfoXml(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      return _decodeUtf16(bytes, littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      return _decodeUtf16(bytes, littleEndian: false);
    }

    final declaredEncoding = detectDeclaredEncoding(Uint8List.fromList(bytes));
    if (declaredEncoding != null) {
      final encoding = Charset.getByName(declaredEncoding);
      if (encoding != null) {
        return encoding.decode(bytes);
      }
    }

    return utf8.decode(bytes, allowMalformed: true);
  }

  String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final codeUnits = <int>[];
    for (var index = 2; index + 1 < bytes.length; index += 2) {
      final first = bytes[index];
      final second = bytes[index + 1];
      codeUnits.add(littleEndian ? first | (second << 8) : second | (first << 8));
    }
    return String.fromCharCodes(codeUnits);
  }
}

final class _ComicInfo {
  const _ComicInfo({this.title, this.authors, this.series, this.number});

  final String? title;
  final List<String>? authors;
  final String? series;
  final String? number;
}

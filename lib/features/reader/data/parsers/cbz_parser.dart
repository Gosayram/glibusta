import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/formats/archive_safety.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';
import 'rust_book_parser.dart';

final class CbzParser implements BookParser {
  static const int _maxComicInfoBytes = 1024 * 1024;

  @override
  bool supports(BookFormat format) => format == BookFormat.cbz || format == BookFormat.cbr;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    if (fileName != null && detectBookFormat(fileName) == BookFormat.cbr) {
      throw const ParserFailure('CBR needs a file path and cannot be parsed from memory');
    }
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
        final contentBytes = file.content as List<int>;
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

  @override
  Future<NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  }) async {
    if (detectBookFormat(filePath) == BookFormat.cbr) {
      return RustBookParser().parseCbrFile(filePath);
    }
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ParserFailure('Файл не найден: $filePath');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw ParserFailure('Файл пуст: $filePath');
      }
      final name = filePath.split('/').last;
      return parse(bytes, fileName: name, forcedEncoding: forcedEncoding);
    } on ParserFailure {
      rethrow;
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл: ${e.message}');
    }
  }

  List<ArchiveFile> _sortedImageFiles(Archive archive) {
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'};
    final files = archive.files.where((f) {
      if (f.isFile) {
        final ext = f.name.split('.').last.toLowerCase();
        return imageExts.contains(ext);
      }
      return false;
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
        utf8.decode(file.content as List<int>, allowMalformed: true),
      );
      String? value(String name) {
        final elements = document.findAllElements(name);
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
}

final class _ComicInfo {
  const _ComicInfo({this.title, this.authors, this.series, this.number});

  final String? title;
  final List<String>? authors;
  final String? series;
  final String? number;
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/formats/archive_safety.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

final class CbzParser implements BookParser {
  @override
  bool supports(BookFormat format) => format == BookFormat.cbz;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveSafety.validateZip(archive);
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
      final title = _titleFromFileName(fileName);
      return NormalizedBook(
        id: fileName ?? 'unknown.cbz',
        title: title,
        authors: const [],
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
}

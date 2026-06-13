import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

final class TxtBookParser implements BookParser {
  final _detector = BookEncodingDetector();

  @override
  bool supports(BookFormat format) => format == BookFormat.txt;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      final textBytes = _extractFromZipIfNeeded(bytes);
      final result = await _detector.detect(
        textBytes,
        fileName: fileName,
        forcedEncoding: forcedEncoding,
      );
      return _textToBook(result.text, fileName: fileName ?? 'unknown.txt');
    } on Object catch (e) {
      throw ParserFailure('Ошибка разбора TXT: $e');
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
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл TXT: ${e.message}');
    }
  }

  Uint8List _extractFromZipIfNeeded(Uint8List bytes) {
    if (bytes.length < 4) return bytes;
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        final txtFile = archive.files.cast<ArchiveFile?>().firstWhere(
          (f) => f!.name.toLowerCase().endsWith('.txt'),
          orElse: () => null,
        );
        if (txtFile != null) {
          return Uint8List.fromList(txtFile.content as List<int>);
        }
      } on Object catch (_) {}
    }
    return bytes;
  }

  NormalizedBook _textToBook(String text, {required String fileName}) {
    return parseTxtFromText(text, fileName: fileName);
  }
}

NormalizedBook parseTxtFromText(String text, {required String fileName}) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final blocks = <ReaderBlock>[];
  for (var i = 0; i < paragraphs.length; i++) {
    blocks.add(ReaderBlock(index: i, text: paragraphs[i]));
  }

  return NormalizedBook(
    id: fileName,
    title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
    authors: const [],
    chapters: [
      ReaderChapter(
        index: 0,
        title: 'Текст',
        blocks: blocks,
      ),
    ],
  );
}

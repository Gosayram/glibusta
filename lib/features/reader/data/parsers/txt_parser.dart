import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

final class TxtBookParser implements BookParser {
  @override
  bool supports(BookFormat format) => format == BookFormat.txt;

  @override
  Future<NormalizedBook> parse(Uint8List bytes, {String? fileName}) async {
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      return _textToBook(text, fileName: fileName ?? 'unknown.txt');
    } on Object catch (e) {
      throw ParserFailure('Ошибка разбора TXT: $e');
    }
  }

  @override
  Future<NormalizedBook> parseFile(String filePath) async {
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
      return parse(bytes, fileName: name);
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл TXT: ${e.message}');
    }
  }

  NormalizedBook _textToBook(String text, {required String fileName}) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final blocks = <ReaderBlock>[];
    for (var i = 0; i < paragraphs.length; i++) {
      blocks.add(
        ReaderBlock(
          index: i,
          text: paragraphs[i],
          type: BlockType.paragraph,
        ),
      );
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
}

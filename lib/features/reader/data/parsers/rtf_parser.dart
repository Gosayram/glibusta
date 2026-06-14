import 'dart:io';
import 'dart:typed_data';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';
import 'txt_parser.dart';

final class RtfBookParser implements BookParser {
  final _detector = BookEncodingDetector();

  @override
  bool supports(BookFormat format) => format == BookFormat.rtf;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      final result = await _detector.detect(
        bytes,
        fileName: fileName,
        forcedEncoding: forcedEncoding,
      );
      final text = rtfToPlainText(result.text);
      return parseTxtFromText(text, fileName: fileName ?? 'unknown.rtf');
    } on Object catch (e) {
      throw ParserFailure('Ошибка разбора RTF: $e');
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
      return parse(
        bytes,
        fileName: filePath.split('/').last,
        forcedEncoding: forcedEncoding,
      );
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл RTF: ${e.message}');
    }
  }
}

String rtfToPlainText(String rtf) {
  final buffer = StringBuffer();
  var index = 0;
  var skipGroupDepth = 0;
  var groupDepth = 0;
  var unicodeSkip = 1;

  while (index < rtf.length) {
    final char = rtf[index];

    if (char == '{') {
      groupDepth++;
      if (_startsWithControlSymbol(rtf, index + 1, '*')) {
        skipGroupDepth = groupDepth;
      }
      index++;
      continue;
    }

    if (char == '}') {
      if (skipGroupDepth == groupDepth) {
        skipGroupDepth = 0;
      }
      groupDepth = groupDepth > 0 ? groupDepth - 1 : 0;
      index++;
      continue;
    }

    if (skipGroupDepth > 0) {
      index++;
      continue;
    }

    if (char == r'\') {
      final parsed = _parseControl(rtf, index, unicodeSkip: unicodeSkip);
      if (parsed.output != null) buffer.write(parsed.output);
      unicodeSkip = parsed.unicodeSkip ?? unicodeSkip;
      index = parsed.nextIndex;
      continue;
    }

    buffer.write(char);
    index++;
  }

  return buffer
      .toString()
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

bool _startsWithControlSymbol(String text, int index, String symbol) {
  return index + 1 < text.length && text[index] == r'\' && text[index + 1] == symbol;
}

({int nextIndex, String? output, int? unicodeSkip}) _parseControl(
  String text,
  int start, {
  required int unicodeSkip,
}) {
  if (start + 1 >= text.length) {
    return (nextIndex: start + 1, output: null, unicodeSkip: null);
  }

  final next = text[start + 1];
  if (next == r'\' || next == '{' || next == '}') {
    return (nextIndex: start + 2, output: next, unicodeSkip: null);
  }

  if (next == "'") {
    final hexEnd = start + 4;
    if (hexEnd <= text.length) {
      final value = int.tryParse(text.substring(start + 2, hexEnd), radix: 16);
      if (value != null) {
        return (nextIndex: hexEnd, output: String.fromCharCode(value), unicodeSkip: null);
      }
    }
    return (nextIndex: (start + 2).clamp(0, text.length), output: null, unicodeSkip: null);
  }

  var index = start + 1;
  while (index < text.length && RegExp('[a-zA-Z]').hasMatch(text[index])) {
    index++;
  }
  final word = text.substring(start + 1, index);

  var negative = false;
  if (index < text.length && text[index] == '-') {
    negative = true;
    index++;
  }

  final numberStart = index;
  while (index < text.length && RegExp(r'\d').hasMatch(text[index])) {
    index++;
  }
  final number = numberStart == index
      ? null
      : int.tryParse('${negative ? '-' : ''}${text.substring(numberStart, index)}');

  if (index < text.length && text[index] == ' ') {
    index++;
  }

  if (word == 'u' && number != null) {
    var skipped = 0;
    while (index < text.length && skipped < unicodeSkip) {
      index++;
      skipped++;
    }
  }

  return (
    nextIndex: index,
    output: switch (word) {
      'par' || 'line' => '\n',
      'tab' => '\t',
      'emdash' => '-',
      'endash' => '-',
      'lquote' => "'",
      'rquote' => "'",
      'ldblquote' => '"',
      'rdblquote' => '"',
      'bullet' => '* ',
      'u' when number != null => String.fromCharCode(number < 0 ? number + 65536 : number),
      _ => null,
    },
    unicodeSkip: word == 'uc' && number != null ? (number < 0 ? 0 : number) : null,
  );
}

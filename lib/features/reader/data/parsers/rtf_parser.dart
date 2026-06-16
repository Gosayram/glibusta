import 'dart:io';
import 'dart:typed_data';

import 'package:fl_charset/fl_charset.dart';

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

const int _maxGroupDepth = 200;
const int _maxControlWordLength = 64;
const int _maxRtfOutputChars = 5 * 1024 * 1024;

String rtfToPlainText(String rtf) {
  final codepage = _extractAnsicpg(rtf);
  final buffer = StringBuffer();
  var index = 0;
  var skipGroupDepth = 0;
  var groupDepth = 0;
  var unicodeSkip = 1;

  while (index < rtf.length) {
    if (buffer.length > _maxRtfOutputChars) break;
    final char = rtf[index];

    if (char == '{') {
      if (groupDepth < _maxGroupDepth) {
        groupDepth++;
        if (_startsWithControlSymbol(rtf, index + 1, '*')) {
          skipGroupDepth = groupDepth;
        }
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
      final parsed = _parseControl(rtf, index, unicodeSkip: unicodeSkip, codepage: codepage);
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

/// Extract the \ansicpg value from the RTF header (e.g. \ansicpg1251).
/// Returns 1252 (Windows-1252) as the default if not found.
int _extractAnsicpg(String rtf) {
  final match = RegExp(r'\\ansicpg(\d+)').firstMatch(rtf);
  if (match != null) {
    return int.tryParse(match.group(1)!) ?? 1252;
  }
  return 1252;
}

bool _startsWithControlSymbol(String text, int index, String symbol) {
  return index + 1 < text.length && text[index] == r'\' && text[index + 1] == symbol;
}

String? _safeFromCharCode(int code) {
  final resolved = code < 0 ? code + 65536 : code;
  if (resolved < 0 || resolved > 0x10FFFF) return null;
  if (resolved >= 0xD800 && resolved <= 0xDFFF) return null;
  return String.fromCharCode(resolved);
}

({int nextIndex, String? output, int? unicodeSkip}) _parseControl(
  String text,
  int start, {
  required int unicodeSkip,
  required int codepage,
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
        return (nextIndex: hexEnd, output: _decodeCodepageByte(value, codepage), unicodeSkip: null);
      }
    }
    return (nextIndex: (start + 2).clamp(0, text.length), output: null, unicodeSkip: null);
  }

  var index = start + 1;
  final wordStart = index;
  while (index < text.length &&
      index - wordStart < _maxControlWordLength &&
      RegExp('[a-zA-Z]').hasMatch(text[index])) {
    index++;
  }
  final word = text.substring(wordStart, index);

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
      'u' when number != null => _safeFromCharCode(number),
      _ => null,
    },
    unicodeSkip: word == 'uc' && number != null ? (number < 0 ? 0 : number) : null,
  );
}

/// Decode a single byte value using the given ANSI codepage.
String _decodeCodepageByte(int value, int codepage) {
  if (value < 0 || value > 0xFF) return String.fromCharCode(value);
  // ASCII range — always safe.
  if (value < 0x80) return String.fromCharCode(value);

  final encodingName = _codepageToEncoding(codepage);
  if (encodingName == null) {
    // Unknown codepage — fall back to treating as Unicode code point (original behavior).
    return String.fromCharCode(value);
  }
  final charset = Charset.getByName(encodingName);
  if (charset != null) {
    return charset.decode(Uint8List.fromList([value]));
  }
  // fl_charset doesn't support this encoding — fallback.
  return String.fromCharCode(value);
}

String? _codepageToEncoding(int codepage) {
  switch (codepage) {
    case 1252:
      return 'windows-1252';
    case 1250:
      return 'windows-1250';
    case 1251:
      return 'windows-1251';
    case 1253:
      return 'windows-1253';
    case 1254:
      return 'windows-1254';
    case 1255:
      return 'windows-1255';
    case 1256:
      return 'windows-1256';
    case 1257:
      return 'windows-1257';
    case 1258:
      return 'windows-1258';
    case 874:
      return 'windows-874';
    case 932:
      return 'shift_jis';
    case 936:
      return 'gb2312';
    case 949:
      return 'euc-kr';
    case 950:
      return 'big5';
    case 1361:
      return 'euc-kr';
    case 866:
      return 'cp866';
    case 20866:
      return 'koi8-r';
    case 21866:
      return 'koi8-u';
    case 28591:
      return 'iso-8859-1';
    case 28592:
      return 'iso-8859-2';
    case 28595:
      return 'iso-8859-5';
    case 28605:
      return 'iso-8859-15';
    case 65001:
      return 'utf-8';
    default:
      return null;
  }
}

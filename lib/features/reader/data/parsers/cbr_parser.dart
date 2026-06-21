import 'dart:typed_data';

import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

class CbrParser implements BookParser {
  String get formatName => 'CBR';

  @override
  bool supports(BookFormat format) => format == BookFormat.cbr;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) {
    throw UnsupportedError(
      'CBR (RAR) format is not supported yet. '
      'The archive package v4.x does not include RAR decoder. '
      'Use CBZ (ZIP) format instead.',
    );
  }

  @override
  Future<NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  }) {
    throw UnsupportedError(
      'CBR (RAR) format is not supported yet. '
      'The archive package v4.x does not include RAR decoder. '
      'Use CBZ (ZIP) format instead.',
    );
  }

  static bool canParseRar(List<int> bytes) {
    if (bytes.length < 7) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x61 &&
        bytes[2] == 0x72 &&
        bytes[3] == 0x21 &&
        bytes[4] == 0x1a &&
        bytes[5] == 0x07 &&
        bytes[6] == 0x00;
  }

  static String getRarErrorMessage() {
    return 'RAR архивы не поддерживаются. Используйте CBZ (ZIP) формат.';
  }
}

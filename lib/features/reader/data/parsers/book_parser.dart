import 'dart:typed_data';

import 'normalized_book.dart';

abstract class BookParser {
  Future<NormalizedBook> parse(Uint8List bytes, {String? fileName});
  Future<NormalizedBook> parseFile(String filePath);
}

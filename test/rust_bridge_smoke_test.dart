@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/rust_book_parser.dart';
import 'package:glibusta/src/rust/api/frb_generated.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(RustLib.init);

  test('parses a TXT fixture through the Flutter Rust bridge', () async {
    final file = File(p.join(Directory.current.path, 'test_results', '431001.txt'));
    expect(await file.exists(), isTrue);

    final book = await RustBookParser().parseFile(file.path);

    expect(book.title, isNotEmpty);
    expect(book.chapters, isNotEmpty);
  });

  test('parses EPUB metadata returned by the Flutter Rust bridge', () async {
    final file = File(p.join(Directory.current.path, 'test_results', '161303.epub'));
    expect(await file.exists(), isTrue);

    final book = await RustBookParser().parseFile(file.path);

    expect(book.title, isNotEmpty);
    expect(book.chapters, isNotEmpty);
    expect(book.metadata, containsPair('language', 'ru'));
  });
}

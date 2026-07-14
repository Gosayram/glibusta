import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/errors/failures.dart';
import 'package:glibusta/features/reader/data/parsers/cbz_parser.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

void main() {
  final parser = CbzParser();

  Uint8List createComicArchive() {
    final archive = Archive()
      ..addFile(ArchiveFile('pages/10.jpg', 1, <int>[10]))
      ..addFile(ArchiveFile('pages/2.png', 1, <int>[2]))
      ..addFile(ArchiveFile('pages/1.webp', 1, <int>[1]))
      ..addFile(ArchiveFile('Thumbs.db', 1, <int>[0]))
      ..addFile(ArchiveFile('info.txt', 1, <int>[0]));
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  test('parses CBZ images in natural filename order and skips non-image files', () async {
    final book = await parser.parse(createComicArchive(), fileName: 'Комикс.cbz');

    expect(book.title, 'Комикс');
    expect(book.chapters, hasLength(1));
    expect(book.chapters.single.blocks, hasLength(3));
    expect(
      book.chapters.single.blocks.map((ReaderBlock block) => block.imageUrl),
      [
        'data:image/webp;base64,AQ==',
        'data:image/png;base64,Ag==',
        'data:image/jpeg;base64,Cg==',
      ],
    );
  });

  test('rejects an archive without comic pages', () async {
    final archive = Archive()..addFile(ArchiveFile('info.txt', 1, <int>[0]));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    await expectLater(
      parser.parse(bytes, fileName: 'empty.cbz'),
      throwsA(isA<ParserFailure>()),
    );
  });

  test('uses ComicInfo.xml metadata when present', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'ComicInfo.xml',
          146,
          utf8.encode('''
            <ComicInfo>
              <Title>Город героев</Title>
              <Writer>Автор</Writer>
              <Series>Серия</Series>
              <Number>7</Number>
            </ComicInfo>
          '''),
        ),
      )
      ..addFile(ArchiveFile('001.png', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'fallback.cbz',
    );

    expect(book.title, 'Город героев');
    expect(book.authors, ['Автор']);
    expect(book.metadata, {'series': 'Серия', 'number': '7'});
  });

  test('routes CBR files to the path-based native RAR parser', () async {
    expect(parser.supports(BookFormat.cbz), isTrue);
    expect(parser.supports(BookFormat.cbr), isTrue);
    await expectLater(
      parser.parse(Uint8List(0), fileName: 'comic.cbr'),
      throwsA(isA<ParserFailure>()),
    );
  });
}

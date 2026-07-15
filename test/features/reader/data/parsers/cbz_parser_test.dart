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

  List<int> utf16LeWithBom(String value) {
    final bytes = <int>[0xff, 0xfe];
    for (final unit in value.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add(unit >> 8);
    }
    return bytes;
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

  test('parses a CBZ archive with a generic ZIP filename', () async {
    final book = await parser.parse(createComicArchive(), fileName: 'comic.zip');

    expect(book.chapters.single.blocks, hasLength(3));
  });

  test('keeps natural page order across nested chapter directories', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('Chapter02/10.jpg', 1, <int>[4]))
      ..addFile(ArchiveFile('Chapter01/2.jpg', 1, <int>[2]))
      ..addFile(ArchiveFile('Chapter02/1.jpg', 1, <int>[3]))
      ..addFile(ArchiveFile('Chapter01/1.jpg', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'nested.cbz',
    );

    expect(
      book.chapters.single.blocks.map((ReaderBlock block) => block.imageUrl),
      [
        'data:image/jpeg;base64,AQ==',
        'data:image/jpeg;base64,Ag==',
        'data:image/jpeg;base64,Aw==',
        'data:image/jpeg;base64,BA==',
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

  test('returns a parser failure for corrupted CBZ bytes', () async {
    await expectLater(
      parser.parse(Uint8List.fromList(<int>[0x50, 0x4b, 0x03]), fileName: 'broken.cbz'),
      throwsA(isA<ParserFailure>()),
    );
  });

  test('uses ComicInfo.xml metadata when present', () async {
    final comicInfo = utf8.encode('''
            <ComicInfo>
              <Title>Город героев</Title>
              <Writer>Автор</Writer>
              <Series>Серия</Series>
              <Number>7</Number>
            </ComicInfo>
          ''');
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'ComicInfo.xml',
          comicInfo.length,
          comicInfo,
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

  test('reads UTF-16 ComicInfo.xml metadata', () async {
    final comicInfo = utf16LeWithBom('<ComicInfo><Title>Комикс</Title></ComicInfo>');
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', comicInfo.length, comicInfo))
      ..addFile(ArchiveFile('001.png', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'comic.cbz',
    );

    expect(book.title, 'Комикс');
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

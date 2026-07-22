import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_charset/fl_charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/errors/failures.dart';
import 'package:glibusta/features/reader/data/parsers/cbz_parser.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

void main() {
  final parser = CbzParser();
  const transparentWebp = 'UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=';

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

  List<int> utf16BeWithBom(String value) {
    final bytes = <int>[0xfe, 0xff];
    for (final unit in value.codeUnits) {
      bytes
        ..add(unit >> 8)
        ..add(unit & 0xff);
    }
    return bytes;
  }

  test('parses CBZ images in natural filename order and skips non-image files', () async {
    final book = await parser.parse(createComicArchive(), fileName: 'Комикс.cbz');

    expect(book.title, 'Комикс');
    expect(book.chapters, hasLength(1));
    expect(book.chapters.single.blocks, hasLength(3));
    expect(book.coverUrl, 'data:image/webp;base64,AQ==');
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

  test('keeps JXL and AVIF pages so the reader can show its image fallback', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('002.avif', 2, <int>[0, 1]))
      ..addFile(ArchiveFile('001.jxl', 2, <int>[0xff, 0x0a]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'modern-codecs.cbz',
    );

    expect(
      book.chapters.single.blocks.map((ReaderBlock block) => block.imageUrl),
      [
        'data:image/jxl;base64,/wo=',
        'data:image/avif;base64,AAE=',
      ],
    );
  });

  test('preserves a transparent WebP page for the platform image decoder', () async {
    final webpBytes = base64Decode(transparentWebp);
    final archive = Archive()..addFile(ArchiveFile('001.webp', webpBytes.length, webpBytes));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'transparent.cbz',
    );

    expect(book.coverUrl, 'data:image/webp;base64,$transparentWebp');
    expect(book.chapters.single.blocks.single.imageUrl, book.coverUrl);
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

  test('reads UTF-16BE ComicInfo.xml metadata', () async {
    final comicInfo = utf16BeWithBom('<ComicInfo><Title>Комикс BE</Title></ComicInfo>');
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', comicInfo.length, comicInfo))
      ..addFile(ArchiveFile('001.png', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'comic.cbz',
    );

    expect(book.title, 'Комикс BE');
  });

  test('preserves Unicode ZIP page names and UTF-8 BOM ComicInfo metadata', () async {
    final comicInfo = <int>[
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode('<ComicInfo><Title>Космический комикс</Title></ComicInfo>'),
    ];
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', comicInfo.length, comicInfo))
      ..addFile(ArchiveFile('страницы/02.png', 1, <int>[2]))
      ..addFile(ArchiveFile('страницы/01.png', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'комикс.cbz',
    );

    expect(book.title, 'Космический комикс');
    expect(
      book.chapters.single.blocks.map((ReaderBlock block) => block.imageUrl),
      <String>[
        'data:image/png;base64,AQ==',
        'data:image/png;base64,Ag==',
      ],
    );
  });

  test('uses the declared ComicInfo.xml Windows-1251 encoding', () async {
    final windows1251 = Charset.getByName('windows-1251')!;
    final comicInfo = windows1251.encode(
      '<?xml version="1.0" encoding="windows-1251"?> '
      '<ComicInfo><Title>Кириллический комикс</Title><Writer>Автор</Writer></ComicInfo>',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', comicInfo.length, comicInfo))
      ..addFile(ArchiveFile('001.png', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'comic.cbz',
    );

    expect(book.title, 'Кириллический комикс');
    expect(book.authors, <String>['Автор']);
  });

  test('reads namespaced ComicInfo.xml metadata', () async {
    final comicInfo = utf8.encode('''
      <ci:ComicInfo xmlns:ci="urn:comic-info">
        <ci:Title>Namespace comic</ci:Title><ci:Writer>A, B</ci:Writer>
      </ci:ComicInfo>
    ''');
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', comicInfo.length, comicInfo))
      ..addFile(ArchiveFile('001.png', 1, <int>[1]));

    final book = await parser.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      fileName: 'comic.cbz',
    );

    expect(book.title, 'Namespace comic');
    expect(book.authors, ['A', 'B']);
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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/features/reader/data/parsers/rust_book_parser.dart';
import 'package:glibusta/features/reader/epub/epub_archive.dart';
import 'package:glibusta/features/reader/epub/epub_image_store.dart';
import 'package:glibusta/features/reader/epub/epub_parser.dart' as new_epub;
import 'package:path/path.dart' as p;

void main() {
  final testDir = p.join(Directory.current.path, 'test_results');

  group('EPUB Parser (new engine)', () {
    test('parses 161303.epub (small)', () async {
      final file = File(p.join(testDir, '161303.epub'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: 161303.epub');

      final tempDir = await Directory.systemTemp.createTemp('epub_test_');
      try {
        final imageStore = EpubImageStore(tempDir);
        final parser = new_epub.CustomEpubParser(imageStore: imageStore);
        final book = await parser.parse(file.path);

        expect(book.title, isNotEmpty);
        expect(book.authors, isNotEmpty);
        expect(book.chapters, isNotEmpty);
        final totalBlocks = book.chapters.fold(0, (sum, ch) => sum + ch.blocks.length);
        expect(totalBlocks, greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses 52496.epub (medium)', () async {
      final file = File(p.join(testDir, '52496.epub'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: 52496.epub');

      final tempDir = await Directory.systemTemp.createTemp('epub_test_');
      try {
        final imageStore = EpubImageStore(tempDir);
        final parser = new_epub.CustomEpubParser(imageStore: imageStore);
        final book = await parser.parse(file.path);

        expect(book.title, isNotEmpty);
        expect(book.authors, isNotEmpty);
        expect(book.chapters, isNotEmpty);
        final totalBlocks = book.chapters.fold(0, (sum, ch) => sum + ch.blocks.length);
        expect(totalBlocks, greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses 280792.epub (large)', () async {
      final file = File(p.join(testDir, '280792.epub'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: 280792.epub');

      final tempDir = await Directory.systemTemp.createTemp('epub_test_');
      try {
        final imageStore = EpubImageStore(tempDir);
        final parser = new_epub.CustomEpubParser(imageStore: imageStore);
        final book = await parser.parse(file.path);

        expect(book.title, isNotEmpty);
        expect(book.chapters, isNotEmpty);
        final totalBlocks = book.chapters.fold(0, (sum, ch) => sum + ch.blocks.length);
        expect(totalBlocks, greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses 181420.epub', () async {
      final file = File(p.join(testDir, '181420.epub'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: 181420.epub');

      final tempDir = await Directory.systemTemp.createTemp('epub_test_');
      try {
        final imageStore = EpubImageStore(tempDir);
        final parser = new_epub.CustomEpubParser(imageStore: imageStore);
        final book = await parser.parse(file.path);

        expect(book.title, isNotEmpty);
        expect(book.authors, isNotEmpty);
        expect(book.chapters, isNotEmpty);
        final totalBlocks = book.chapters.fold(0, (sum, ch) => sum + ch.blocks.length);
        expect(totalBlocks, greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('EPUB archive opens and reads content', () async {
      final file = File(p.join(testDir, '161303.epub'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: 161303.epub');

      final archive = await EpubArchive.open(file.path);
      final containerPath = archive.findFile('META-INF/container.xml');
      expect(containerPath, isNotNull);

      final containerText = archive.readText('META-INF/container.xml');
      expect(containerText, contains('container'));
      expect(containerText, contains('rootfile'));
    });
  });

  group('FB2 Parser — FB2.ZIP detection', () {
    test('detects ZIP magic bytes in FB2.ZIP files', () async {
      for (final name in ['161303.fb2', '181420.fb2', '52496.fb2']) {
        final file = File(p.join(testDir, name));
        final exists = await file.exists();
        expect(exists, isTrue, reason: 'Missing fixture: $name');

        final bytes = await file.readAsBytes();
        expect(bytes.length, greaterThan(100), reason: '$name should be non-empty');
        expect(bytes[0], 0x50, reason: '$name should start with P (ZIP magic)');
        expect(bytes[1], 0x4B, reason: '$name should start with K (ZIP magic)');
      }
    });

    test('detects plain UTF-8 FB2', () async {
      final file = File(p.join(testDir, '25. Джек Ричер, или Синяя луна.fb2'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: plain FB2 file');

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));

      final header = String.fromCharCodes(bytes.sublist(0, 50));
      expect(header, contains('<?xml'));
      expect(header, contains('UTF-8'));
    });
  });

  group('FB2 Parser — content parsing', () {
    test('parses plain FB2 and extracts metadata', () async {
      final file = File(p.join(testDir, '25. Джек Ричер, или Синяя луна.fb2'));
      expect(await file.exists(), isTrue, reason: 'Missing fixture: plain FB2 file');

      final parser = RustBookParser();
      final book = await parser.parseFile(file.path);

      expect(book.title, isNotEmpty);
      expect(book.authors, isNotEmpty);
      expect(book.chapters, isNotEmpty);
    });

    test('parses FB2.ZIP and extracts metadata', () async {
      for (final name in ['161303.fb2', '52496.fb2']) {
        final file = File(p.join(testDir, name));
        if (!await file.exists()) {
          expect(await file.exists(), isTrue, reason: 'Missing fixture: $name');
          continue;
        }

        final parser = RustBookParser();
        final book = await parser.parseFile(file.path);

        expect(book.title, isNotEmpty, reason: '$name should have a title');
        expect(book.chapters, isNotEmpty, reason: '$name should have chapters');
      }
    });
  });

  group('Encoding Detection', () {
    test('detects UTF-8 BOM', () async {
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);
    });

    test('detects UTF-16 LE BOM', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x48, 0x00]);
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xFE);
    });

    test('detects UTF-16 BE BOM', () {
      final bytes = Uint8List.fromList([0xFE, 0xFF, 0x00, 0x48]);
      expect(bytes[0], 0xFE);
      expect(bytes[1], 0xFF);
    });

    test('detects XML encoding declaration', () {
      final sample = '<?xml version="1.0" encoding="windows-1251"?>';
      final match = RegExp(
        r'''<\?xml[^>]+encoding\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(sample);
      expect(match, isNotNull);
      expect(match!.group(1), 'windows-1251');
    });

    test('detects HTML meta charset', () {
      final sample = '<meta charset="koi8-r">';
      final match = RegExp(
        r'''charset\s*=\s*["']?([a-zA-Z0-9_\-]+)''',
        caseSensitive: false,
      ).firstMatch(sample);
      expect(match, isNotNull);
      expect(match!.group(1), 'koi8-r');
    });
  });

  group('Format Detection', () {
    test('detects .epub extension', () {
      expect(detectBookFormat('book.epub'), BookFormat.epub);
    });

    test('detects .fb2 extension', () {
      expect(detectBookFormat('book.fb2'), BookFormat.fb2);
    });

    test('detects .txt extension', () {
      expect(detectBookFormat('book.txt'), BookFormat.txt);
    });

    test('detects .pdf extension', () {
      expect(detectBookFormat('book.pdf'), BookFormat.pdf);
    });

    test('detects .mobi extension', () {
      expect(detectBookFormat('book.mobi'), BookFormat.mobi);
    });

    test('detects .rtf extension', () {
      expect(detectBookFormat('book.rtf'), BookFormat.rtf);
    });

    test('detects .djvu extension', () {
      expect(detectBookFormat('book.djvu'), BookFormat.djvu);
      expect(detectBookFormat('book.djv'), BookFormat.djvu);
    });
  });
}

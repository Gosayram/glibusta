import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/fb2_parser.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/features/reader/data/parsers/txt_parser.dart';
import 'package:glibusta/features/reader/epub/epub_image_store.dart';
import 'package:glibusta/features/reader/epub/epub_parser.dart' as new_epub;
import 'package:path/path.dart' as p;

void main() {
  final testDir = p.join(Directory.current.path, 'test_results');

  group('FB2 — all files', () {
    final files = Directory(testDir)
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.fb2'),
        )
        .toList();

    for (final file in files) {
      final name = p.basename(file.path);
      test(name, () async {
        final parser = Fb2Parser();
        final book = await parser.parseFile(file.path);
        expect(book.title, isNotEmpty);
        expect(book.authors, isNotEmpty);
        expect(book.chapters, isNotEmpty);
        final total = book.chapters.fold(0, (s, ch) => s + ch.blocks.length);
        expect(total, greaterThan(0), reason: 'should have blocks');
      });
    }
  });

  group('EPUB — all files', () {
    final files = Directory(testDir)
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.epub'),
        )
        .toList();

    for (final file in files) {
      final name = p.basename(file.path);
      test(name, () async {
        final tempDir = await Directory.systemTemp.createTemp('epub_all_');
        try {
          final imageStore = EpubImageStore(tempDir);
          final parser = new_epub.CustomEpubParser(imageStore: imageStore);
          final book = await parser.parse(file.path);
          expect(book.title, isNotEmpty);
          expect(book.authors, isNotEmpty);
          expect(book.chapters, isNotEmpty);
          final total = book.chapters.fold(0, (s, ch) => s + ch.blocks.length);
          expect(total, greaterThan(0));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    }
  });

  group('TXT — all files', () {
    final files = Directory(testDir)
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.txt'),
        )
        .toList();

    for (final file in files) {
      final name = p.basename(file.path);
      test(name, () async {
        final bytes = await file.readAsBytes();
        final header = bytes.sublist(0, 4);
        final isZip =
            header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04;

        if (isZip) {
          // ignore: avoid_print
          print('  NOTE: $name is actually a ZIP archive');
        }

        final parser = TxtBookParser();
        final book = await parser.parseFile(file.path);
        expect(book.title, isNotEmpty);
        expect(book.chapters, isNotEmpty);
        final total = book.chapters.fold(0, (s, ch) => s + ch.blocks.length);
        expect(total, greaterThan(0), reason: 'should have content blocks');
      });
    }
  });

  group('MOBI — detected as mobi format', () {
    final files = Directory(testDir)
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.mobi'),
        )
        .toList();

    for (final file in files) {
      final name = p.basename(file.path);
      test('$name detected as mobi', () {
        expect(detectBookFormat(file.path), BookFormat.mobi);
      });
    }
  });

  group('Format detection', () {
    test('detects all known extensions', () {
      expect(detectBookFormat('book.epub'), BookFormat.epub);
      expect(detectBookFormat('book.fb2'), BookFormat.fb2);
      expect(detectBookFormat('book.txt'), BookFormat.txt);
      expect(detectBookFormat('book.pdf'), BookFormat.pdf);
      expect(detectBookFormat('book.mobi'), BookFormat.mobi);
      expect(detectBookFormat('book.zip'), BookFormat.fb2);
    });
  });
}

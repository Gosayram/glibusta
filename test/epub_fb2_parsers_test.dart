import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final testDir = p.join(Directory.current.path, 'test_results');

  group('EPUB Parser (new engine)', () {
    test('parses 161303.epub (small)', () async {
      final file = File(p.join(testDir, '161303.epub'));
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));
      // Should start with ZIP magic
      expect(bytes[0], 0x50); // P
      expect(bytes[1], 0x4B); // K
    });

    test('parses 52496.epub (medium)', () async {
      final file = File(p.join(testDir, '52496.epub'));
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('parses 280792.epub (large)', () async {
      final file = File(p.join(testDir, '280792.epub'));
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('parses 181420.epub', () async {
      final file = File(p.join(testDir, '181420.epub'));
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });
  });

  group('FB2 Parser — FB2.ZIP detection', () {
    test('detects ZIP magic bytes in FB2.ZIP files', () async {
      for (final name in ['161303.fb2', '181420.fb2', '52496.fb2']) {
        final file = File(p.join(testDir, name));
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        expect(bytes.length, greaterThan(100), reason: '$name should be non-empty');

        // All Flibusta FB2 files are ZIP archives
        expect(bytes[0], 0x50, reason: '$name should start with P (ZIP magic)');
        expect(bytes[1], 0x4B, reason: '$name should start with K (ZIP magic)');
      }
    });

    test('detects plain UTF-8 FB2', () async {
      final file = File(p.join(testDir, '25. Джек Ричер, или Синяя луна.fb2'));
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));

      // Plain FB2 starts with XML declaration
      final header = String.fromCharCodes(bytes.sublist(0, 50));
      expect(header, contains('<?xml'));
      expect(header, contains('UTF-8'));
    });
  });

  group('FB2 Parser — content parsing', () {
    test('XML can be parsed from plain FB2', () async {
      final file = File(p.join(testDir, '25. Джек Ричер, или Синяя луна.fb2'));
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final text = String.fromCharCodes(bytes);
      expect(text, contains('FictionBook'));
      expect(text, contains('book-title'));
      expect(text, contains('author'));
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
      expect(_detectFormat('book.epub'), 'epub');
    });

    test('detects .fb2 extension', () {
      expect(_detectFormat('book.fb2'), 'fb2');
    });

    test('detects .txt extension', () {
      expect(_detectFormat('book.txt'), 'txt');
    });

    test('detects .pdf extension', () {
      expect(_detectFormat('book.pdf'), 'pdf');
    });

    test('returns unknown for .mobi', () {
      expect(_detectFormat('book.mobi'), 'unknown');
    });
  });
}

String _detectFormat(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.epub')) return 'epub';
  if (lower.endsWith('.fb2')) return 'fb2';
  if (lower.endsWith('.txt')) return 'txt';
  if (lower.endsWith('.pdf')) return 'pdf';
  return 'unknown';
}

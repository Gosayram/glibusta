import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/data/parsers/rust_book_parser.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/epub/epub_book_adapter.dart';
import 'package:glibusta/features/reader/epub/epub_image_store.dart';
import 'package:glibusta/features/reader/epub/epub_parser.dart' as new_epub;
import 'package:glibusta/src/rust/api/frb_generated.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(RustLib.init);

  final testDir = p.join(Directory.current.path, 'test_results');

  test('ReaderBlock JSON round trip preserves source text exactly', () {
    const block = ReaderBlock(
      index: 0,
      text: 'А. С. Пушкин\nи  1 000 строк',
      type: BlockType.preformatted,
    );

    final restored = ReaderBlock.fromJson(block.toJson());

    expect(restored.text, block.text);
  });

  group('EPUB → NormalizedBook → serialization roundtrip', () {
    final epubFiles = Directory(
      testDir,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.epub')).toList();

    for (final file in epubFiles) {
      final name = p.basename(file.path);
      test('$name: parse → serialize → deserialize preserves content', () async {
        final tempDir = await Directory.systemTemp.createTemp('reader_pipe_');
        try {
          final imageStore = EpubImageStore(tempDir);
          final parser = new_epub.CustomEpubParser(imageStore: imageStore);
          final epubBook = await parser.parse(file.path);

          final adapter = EpubBookAdapter();
          final normalized = adapter.toNormalizedBook(epubBook, 'test-$name');

          expect(normalized.title, isNotEmpty, reason: '$name: title should not be empty');
          expect(normalized.chapters, isNotEmpty, reason: '$name: chapters should not be empty');

          final totalBlocks = normalized.chapters.fold(0, (s, ch) => s + ch.blocks.length);
          expect(totalBlocks, greaterThan(0), reason: '$name: should have content blocks');

          for (final chapter in normalized.chapters) {
            expect(chapter.index, isA<int>());
            expect(chapter.title, isA<String>());
            expect(chapter.blocks, isA<List<ReaderBlock>>());
          }

          final json = normalized.toJson();
          final deserialized = NormalizedBook.fromJson(json);

          expect(deserialized.title, normalized.title);
          expect(deserialized.authors, normalized.authors);
          expect(deserialized.chapters.length, normalized.chapters.length);

          for (var i = 0; i < normalized.chapters.length; i++) {
            final orig = normalized.chapters[i];
            final deser = deserialized.chapters[i];
            expect(deser.index, orig.index, reason: '$name: chapter $i index');
            expect(deser.title, orig.title, reason: '$name: chapter $i title');
            expect(
              deser.blocks.length,
              orig.blocks.length,
              reason: '$name: chapter $i block count',
            );

            for (var j = 0; j < orig.blocks.length; j++) {
              expect(
                deser.blocks[j].text,
                orig.blocks[j].text,
                reason: '$name: chapter $i block $j text',
              );
              expect(
                deser.blocks[j].type,
                orig.blocks[j].type,
                reason: '$name: chapter $i block $j type',
              );
            }
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    }
  });

  group('EPUB adapter preserves rich text formatting', () {
    test('at least one EPUB has blocks with richSpans', () async {
      final epubFiles = Directory(
        testDir,
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.epub')).toList();

      var foundAny = false;
      for (final file in epubFiles) {
        final tempDir = await Directory.systemTemp.createTemp('rich_text_');
        try {
          final imageStore = EpubImageStore(tempDir);
          final parser = new_epub.CustomEpubParser(imageStore: imageStore);
          final epubBook = await parser.parse(file.path);
          final adapter = EpubBookAdapter();
          final normalized = adapter.toNormalizedBook(epubBook, 'rich-test');

          for (final chapter in normalized.chapters) {
            for (final block in chapter.blocks) {
              if (block.richSpans != null && block.richSpans!.isNotEmpty) {
                foundAny = true;
                final firstSpan = block.richSpans!.first;
                expect(firstSpan.text, isNotEmpty);
                break;
              }
            }
            if (foundAny) break;
          }
          if (foundAny) break;
        } finally {
          await tempDir.delete(recursive: true);
        }
      }

      expect(foundAny, isTrue, reason: 'At least one EPUB should have paragraphs with formatting');
    });
  });

  group('RichSpan serialization roundtrip', () {
    test('RichSpan toJson/fromJson preserves all fields', () {
      const span = RichSpan(
        text: 'Hello ',
        bold: true,
        href: 'http://example.com',
      );
      final json = span.toJson();
      final restored = RichSpan.fromJson(json);

      expect(restored.text, 'Hello ');
      expect(restored.bold, isTrue);
      expect(restored.italic, isFalse);
      expect(restored.superscript, isFalse);
      expect(restored.href, 'http://example.com');
    });

    test('RichSpan defaults are correct', () {
      const span = RichSpan(text: 'Plain');
      expect(span.bold, isFalse);
      expect(span.italic, isFalse);
      expect(span.superscript, isFalse);
      expect(span.href, isNull);
    });

    test('RichSpan JSON omits false booleans', () {
      const span = RichSpan(text: 'Bold', bold: true);
      final json = span.toJson();
      expect(json.containsKey('italic'), isFalse);
      expect(json.containsKey('superscript'), isFalse);
      expect(json.containsKey('href'), isFalse);
    });
  });

  group('FB2 → NormalizedBook → serialization roundtrip', () {
    final fb2Files = Directory(
      testDir,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.fb2')).toList();

    for (final file in fb2Files) {
      final name = p.basename(file.path);
      test('$name: parse → serialize → deserialize preserves content', () async {
        final parser = RustBookParser();
        final normalized = await parser.parseFile(file.path);

        expect(normalized.title, isNotEmpty, reason: '$name: title should not be empty');
        expect(normalized.chapters, isNotEmpty, reason: '$name: chapters should not be empty');

        final totalBlocks = normalized.chapters.fold(0, (s, ch) => s + ch.blocks.length);
        expect(totalBlocks, greaterThan(0), reason: '$name: should have content blocks');

        final json = normalized.toJson();
        final deserialized = NormalizedBook.fromJson(json);

        expect(deserialized.title, normalized.title);
        expect(deserialized.chapters.length, normalized.chapters.length);

        for (var i = 0; i < normalized.chapters.length; i++) {
          expect(
            deserialized.chapters[i].blocks.length,
            normalized.chapters[i].blocks.length,
            reason: '$name: chapter $i block count',
          );
        }
      });
    }
  });

  group('TXT → NormalizedBook → serialization roundtrip', () {
    test('431001.txt: parse → serialize → deserialize preserves content', () async {
      final file = File(p.join(testDir, '431001.txt'));
      expect(await file.exists(), isTrue);

      final parser = RustBookParser();
      final normalized = await parser.parseFile(file.path);

      expect(normalized.title, isNotEmpty);
      expect(normalized.chapters, isNotEmpty);

      final totalBlocks = normalized.chapters.fold(0, (s, ch) => s + ch.blocks.length);
      expect(totalBlocks, greaterThan(0), reason: 'TXT should have content blocks');

      final json = normalized.toJson();
      final deserialized = NormalizedBook.fromJson(json);

      expect(deserialized.title, normalized.title);
      expect(deserialized.chapters.length, normalized.chapters.length);

      final origBlocks = normalized.chapters.first.blocks;
      final deserBlocks = deserialized.chapters.first.blocks;
      expect(deserBlocks.length, origBlocks.length);

      for (var i = 0; i < origBlocks.length.clamp(0, 5); i++) {
        expect(deserBlocks[i].text, origBlocks[i].text, reason: 'block $i text mismatch');
      }
    });
  });

  group('NormalizedBook edge cases', () {
    test('empty chapters list serializes and deserializes', () {
      const book = NormalizedBook(
        id: 'empty',
        title: 'Empty',
        authors: [],
      );
      final json = book.toJson();
      final restored = NormalizedBook.fromJson(json);

      expect(restored.chapters, isEmpty);
      expect(restored.title, 'Empty');
    });

    test('chapter with empty blocks serializes correctly', () {
      const book = NormalizedBook(
        id: 'empty-blocks',
        title: 'Empty Blocks',
        authors: ['Author'],
        chapters: [
          ReaderChapter(
            index: 0,
            title: 'Ch1',
            blocks: [],
          ),
        ],
      );
      final json = book.toJson();
      final restored = NormalizedBook.fromJson(json);

      expect(restored.chapters.length, 1);
      expect(restored.chapters[0].blocks, isEmpty);
    });

    test('all BlockType values roundtrip correctly', () {
      for (final type in BlockType.values) {
        final block = ReaderBlock(
          index: 0,
          text: 'test',
          type: type,
          imageUrl: type == BlockType.image ? '/path/img.jpg' : null,
        );
        final json = block.toJson();
        final restored = ReaderBlock.fromJson(json);
        expect(restored.type, type, reason: 'BlockType.${type.name}');
      }
    });

    test('ReaderPosition clamp works', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 100,
        paragraphIndex: 50,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 5);
      expect(clamped.chapterIndex, 4);
      expect(clamped.paragraphIndex, 50);
    });
  });

  group('EPUB adapter — block type mapping', () {
    test('all epub block types map to correct NormalizedBook block types', () async {
      final file = File(p.join(testDir, '161303.epub'));
      expect(await file.exists(), isTrue);

      final tempDir = await Directory.systemTemp.createTemp('block_map_');
      try {
        final imageStore = EpubImageStore(tempDir);
        final parser = new_epub.CustomEpubParser(imageStore: imageStore);
        final epubBook = await parser.parse(file.path);
        final adapter = EpubBookAdapter();
        final normalized = adapter.toNormalizedBook(epubBook, 'block-map');

        final blockTypes = <BlockType>{};
        for (final chapter in normalized.chapters) {
          for (final block in chapter.blocks) {
            blockTypes.add(block.type);
          }
        }

        expect(blockTypes, contains(BlockType.paragraph));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('NormalizedBookMetadata', () {
    test('toMetadata creates correct metadata from book', () {
      const book = NormalizedBook(
        id: 'test-id',
        title: 'Test Title',
        authors: ['Author 1', 'Author 2'],
        description: 'Description',
        coverUrl: '/cover.jpg',
        chapters: [
          ReaderChapter(index: 0, title: 'Ch1', blocks: []),
          ReaderChapter(index: 1, title: 'Ch2', blocks: []),
        ],
        metadata: {'language': 'ru'},
      );

      final meta = book.toMetadata();
      expect(meta.id, 'test-id');
      expect(meta.title, 'Test Title');
      expect(meta.authors, ['Author 1', 'Author 2']);
      expect(meta.description, 'Description');
      expect(meta.coverUrl, '/cover.jpg');
      expect(meta.chapterCount, 2);
      expect(meta.chapterTitles, ['Ch1', 'Ch2']);
      expect(meta.metadata, {'language': 'ru'});
    });

    test('NormalizedBookMetadata serialization roundtrip', () {
      const meta = NormalizedBookMetadata(
        id: 'meta-id',
        title: 'Meta Title',
        authors: ['A'],
        description: 'Desc',
        chapterCount: 3,
        chapterTitles: ['C1', 'C2', 'C3'],
        metadata: {'key': 'value'},
      );

      final json = meta.toJson();
      final restored = NormalizedBookMetadata.fromJson(json);

      expect(restored.id, meta.id);
      expect(restored.title, meta.title);
      expect(restored.chapterCount, meta.chapterCount);
      expect(restored.chapterTitles, meta.chapterTitles);
    });
  });
}

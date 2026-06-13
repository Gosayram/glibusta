import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

void main() {
  group('NormalizedBook', () {
    test('toJson/fromJson roundtrip', () {
      const book = NormalizedBook(
        id: 'test-1',
        title: 'Тестовая книга',
        authors: ['Автор 1', 'Автор 2'],
        description: 'Описание',
        coverUrl: 'https://example.com/cover.jpg',
        chapters: [
          ReaderChapter(
            index: 0,
            title: 'Глава 1',
            blocks: [
              ReaderBlock(index: 0, text: 'Текст параграфа'),
              ReaderBlock(
                index: 1,
                text: '',
                type: BlockType.image,
                imageUrl: 'https://example.com/img.jpg',
              ),
            ],
          ),
          ReaderChapter(
            index: 1,
            title: 'Глава 2',
            blocks: [
              ReaderBlock(index: 0, text: 'Другой текст'),
            ],
          ),
        ],
        metadata: {'language': 'ru'},
      );

      final json = book.toJson();
      final restored = NormalizedBook.fromJson(json);

      expect(restored.id, book.id);
      expect(restored.title, book.title);
      expect(restored.authors, book.authors);
      expect(restored.description, book.description);
      expect(restored.coverUrl, book.coverUrl);
      expect(restored.chapters.length, 2);
      expect(restored.chapters[0].title, 'Глава 1');
      expect(restored.chapters[0].blocks.length, 2);
      expect(restored.chapters[0].blocks[1].imageUrl, 'https://example.com/img.jpg');
      expect(restored.metadata, {'language': 'ru'});
    });

    test('fromJson handles null fields', () {
      final json = {
        'id': 'x',
        'title': 'X',
        'authors': null,
        'description': null,
        'coverUrl': null,
        'chapters': null,
        'metadata': null,
      };
      final book = NormalizedBook.fromJson(json);
      expect(book.authors, isEmpty);
      expect(book.chapters, isEmpty);
      expect(book.description, isNull);
      expect(book.coverUrl, isNull);
    });

    test('toMetadata extracts correct fields', () {
      const book = NormalizedBook(
        id: 'b1',
        title: 'Book',
        authors: ['A'],
        chapters: [
          ReaderChapter(index: 0, title: 'Ch1', blocks: []),
          ReaderChapter(index: 1, title: 'Ch2', blocks: []),
        ],
      );
      final meta = book.toMetadata();
      expect(meta.id, 'b1');
      expect(meta.chapterCount, 2);
      expect(meta.chapterTitles, ['Ch1', 'Ch2']);
    });
  });

  group('ReaderChapter', () {
    test('toJson/fromJson roundtrip', () {
      const chapter = ReaderChapter(
        index: 3,
        title: 'Тест',
        blocks: [
          ReaderBlock(index: 0, text: 'text', type: BlockType.heading),
        ],
      );
      final json = chapter.toJson();
      final restored = ReaderChapter.fromJson(json);
      expect(restored.index, 3);
      expect(restored.title, 'Тест');
      expect(restored.blocks.length, 1);
      expect(restored.blocks[0].type, BlockType.heading);
    });
  });

  group('ReaderBlock', () {
    test('default type is paragraph', () {
      const block = ReaderBlock(index: 0, text: 'hello');
      expect(block.type, BlockType.paragraph);
      expect(block.imageUrl, isNull);
      expect(block.noteRef, isNull);
      expect(block.richSpans, isNull);
    });

    test('toJson/fromJson roundtrip with all fields', () {
      const block = ReaderBlock(
        index: 5,
        text: 'text',
        type: BlockType.footnote,
        imageUrl: 'img.png',
        noteRef: 'ref1',
        richSpans: [
          RichSpan(text: 'bold', bold: true),
          RichSpan(text: 'italic', italic: true),
        ],
      );
      final json = block.toJson();
      final restored = ReaderBlock.fromJson(json);
      expect(restored.index, 5);
      expect(restored.type, BlockType.footnote);
      expect(restored.imageUrl, 'img.png');
      expect(restored.noteRef, 'ref1');
      expect(restored.richSpans!.length, 2);
      expect(restored.richSpans![0].bold, isTrue);
      expect(restored.richSpans![1].italic, isTrue);
    });

    test('unknown type falls back to paragraph', () {
      final json = {
        'index': 0,
        'text': 'x',
        'type': 'nonexistent',
      };
      final block = ReaderBlock.fromJson(json);
      expect(block.type, BlockType.paragraph);
    });
  });

  group('RichSpan', () {
    test('default values', () {
      const span = RichSpan(text: 'hello');
      expect(span.bold, isFalse);
      expect(span.italic, isFalse);
      expect(span.superscript, isFalse);
      expect(span.href, isNull);
    });

    test('toJson omits false/nil fields', () {
      const span = RichSpan(text: 'hello');
      final json = span.toJson();
      expect(json.containsKey('bold'), isFalse);
      expect(json.containsKey('italic'), isFalse);
      expect(json.containsKey('superscript'), isFalse);
      expect(json.containsKey('href'), isFalse);
    });

    test('toJson includes true fields', () {
      const span = RichSpan(
        text: 'link',
        bold: true,
        superscript: true,
        href: 'https://example.com',
      );
      final json = span.toJson();
      expect(json['bold'], true);
      expect(json['superscript'], true);
      expect(json['href'], 'https://example.com');
    });

    test('fromJson roundtrip', () {
      const span = RichSpan(
        text: 'test',
        bold: true,
        italic: true,
        superscript: true,
        href: '/ref',
      );
      final json = span.toJson();
      final restored = RichSpan.fromJson(json);
      expect(restored.text, 'test');
      expect(restored.bold, isTrue);
      expect(restored.italic, isTrue);
      expect(restored.superscript, isTrue);
      expect(restored.href, '/ref');
    });

    test('fromJson with empty json', () {
      final span = RichSpan.fromJson({'text': 'x'});
      expect(span.bold, isFalse);
      expect(span.italic, isFalse);
      expect(span.superscript, isFalse);
      expect(span.href, isNull);
    });
  });

  group('NormalizedBookMetadata', () {
    test('toJson/fromJson roundtrip', () {
      const meta = NormalizedBookMetadata(
        id: 'b1',
        title: 'Book',
        authors: ['A'],
        description: 'Desc',
        coverUrl: 'cover.jpg',
        chapterCount: 3,
        chapterTitles: ['C1', 'C2', 'C3'],
        metadata: {'key': 'value'},
      );
      final json = meta.toJson();
      final restored = NormalizedBookMetadata.fromJson(json);
      expect(restored.id, 'b1');
      expect(restored.chapterCount, 3);
      expect(restored.chapterTitles.length, 3);
      expect(restored.metadata, {'key': 'value'});
    });
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'normalized_book.dart';

class EpubParser implements BookParser {
  @override
  Future<NormalizedBook> parse(Uint8List bytes, {String? fileName}) async {
    try {
      final epubBook = await EpubReader.readBook(bytes);
      return _convertToNormalized(epubBook);
    } on FormatException catch (e) {
      throw ParserFailure('Неверный формат EPUB: ${e.message}');
    } on Object catch (e) {
      throw ParserFailure('Неожиданная ошибка при разборе EPUB: $e');
    }
  }

  @override
  Future<NormalizedBook> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return parse(bytes, fileName: filePath.split('/').last);
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл EPUB: ${e.message}');
    }
  }

  NormalizedBook _convertToNormalized(EpubBook epubBook) {
    final chapters = <ReaderBlock>[];
    int blockIndex = 0;

    if (epubBook.Chapters != null) {
      for (final chapter in epubBook.Chapters!) {
        if (chapter.HtmlContent != null) {
          final doc = html_parser.parse(chapter.HtmlContent!);
          final paragraphs = doc.querySelectorAll('p, h1, h2, h3, h4, h5, h6');

          for (final para in paragraphs) {
            final text = para.text.trim();
            if (text.isNotEmpty) {
              chapters.add(
                ReaderBlock(
                  index: blockIndex++,
                  text: text,
                  type: _getBlockType(para.localName),
                ),
              );
            }
          }
        }
      }
    }

    return NormalizedBook(
      id: epubBook.Title ?? 'unknown',
      title: epubBook.Title ?? 'Unknown Title',
      authors: epubBook.Author != null ? [epubBook.Author!] : [],
      coverUrl: epubBook.CoverImage != null ? 'embedded' : null,
      chapters: [
        ReaderChapter(
          index: 0,
          title: 'Main Content',
          blocks: chapters,
        ),
      ],
      metadata: {},
    );
  }

  BlockType _getBlockType(String? tagName) {
    switch (tagName) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return BlockType.heading;
      case 'img':
        return BlockType.image;
      case 'blockquote':
        return BlockType.quote;
      default:
        return BlockType.paragraph;
    }
  }
}

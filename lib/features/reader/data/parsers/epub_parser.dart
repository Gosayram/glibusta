import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;

import 'book_parser.dart';
import 'normalized_book.dart';

class EpubParser implements BookParser {
  @override
  Future<NormalizedBook> parse(Uint8List bytes, {String? fileName}) async {
    final epubBook = await EpubReader.readBook(bytes);
    return _convertToNormalized(epubBook);
  }

  @override
  Future<NormalizedBook> parseFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return parse(bytes, fileName: filePath.split('/').last);
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

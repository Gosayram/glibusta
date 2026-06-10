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
    } on RangeError catch (e) {
      throw ParserFailure('Повреждённый EPUB файл: ${e.message}');
    } on StateError catch (e) {
      throw ParserFailure('Ошибка структуры EPUB: ${e.message}');
    } on Object catch (e) {
      throw ParserFailure('Неожиданная ошибка при разборе EPUB: $e');
    }
  }

  @override
  Future<NormalizedBook> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ParserFailure('Файл не найден: $filePath');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw ParserFailure('Файл пуст: $filePath');
      }
      return parse(bytes, fileName: filePath.split('/').last);
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл EPUB: ${e.message}');
    }
  }

  NormalizedBook _convertToNormalized(EpubBook epubBook) {
    final chapters = <ReaderChapter>[];
    if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
      var chapterIndex = 0;
      for (final chapter in epubBook.Chapters!) {
        chapters.addAll(_convertChapter(chapter, ref: chapterIndex++));
      }
    }

    final metadata = <String, dynamic>{
      'coverImage': epubBook.CoverImage != null,
    };
    if (epubBook.Schema?.Package?.Metadata != null) {
      final meta = epubBook.Schema!.Package!.Metadata!;
      metadata.addAll({
        'description': meta.Description,
        'publishers': meta.Publishers,
        'languages': meta.Languages,
        'subjects': meta.Subjects,
        'rights': meta.Rights,
      });
    }

    return NormalizedBook(
      id: epubBook.Title ?? 'unknown',
      title: epubBook.Title ?? 'Unknown Title',
      authors: _authorsFromEpub(epubBook),
      description: epubBook.Schema?.Package?.Metadata?.Description,
      coverUrl: epubBook.CoverImage != null ? 'embedded' : null,
      chapters: chapters.isEmpty
          ? [
              const ReaderChapter(
                index: 0,
                title: 'Main Content',
                blocks: [],
              ),
            ]
          : chapters,
      metadata: metadata,
    );
  }

  List<ReaderChapter> _convertChapter(EpubChapter chapter, {required int ref}) {
    final result = <ReaderChapter>[];
    final title = chapter.Title?.trim().isNotEmpty == true
        ? chapter.Title!.trim()
        : 'Chapter ${ref + 1}';
    result.add(
      ReaderChapter(
        index: ref,
        title: title,
        blocks: _convertBlocks(chapter.HtmlContent),
      ),
    );

    if (chapter.SubChapters != null) {
      var subIndex = 1;
      for (final subChapter in chapter.SubChapters!) {
        final nestedTitle = subChapter.Title?.trim().isNotEmpty == true
            ? '$title — ${subChapter.Title!.trim()}'
            : '$title.$subIndex';
        result.add(
          ReaderChapter(
            index: result.length,
            title: nestedTitle,
            blocks: _convertBlocks(subChapter.HtmlContent),
          ),
        );
        subIndex++;
      }
    }

    return result;
  }

  List<ReaderBlock> _convertBlocks(String? htmlContent) {
    if (htmlContent == null || htmlContent.trim().isEmpty) return const [];
    final doc = html_parser.parse(htmlContent);
    final nodes = doc.querySelectorAll('p, h1, h2, h3, h4, h5, h6, img, blockquote, div, li');
    final blocks = <ReaderBlock>[];
    for (final node in nodes) {
      if (node.localName == 'img') {
        final src = node.attributes['src'] ?? node.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          blocks.add(
            ReaderBlock(
              index: blocks.length,
              text: '',
              type: BlockType.image,
              imageUrl: src,
            ),
          );
        }
        continue;
      }
      final text = node.text.trim();
      if (text.isNotEmpty) {
        blocks.add(
          ReaderBlock(
            index: blocks.length,
            text: text,
            type: _getBlockType(node.localName),
          ),
        );
      }
    }
    return blocks;
  }

  List<String> _authorsFromEpub(EpubBook epubBook) {
    if (epubBook.AuthorList != null && epubBook.AuthorList!.isNotEmpty) {
      return epubBook.AuthorList!.whereType<String>().where((a) => a.trim().isNotEmpty).toList();
    }
    if (epubBook.Author != null && epubBook.Author!.trim().isNotEmpty) {
      return [epubBook.Author!];
    }
    return epubBook.Schema?.Package?.Metadata?.Creators
            ?.map((creator) => creator.Creator)
            .whereType<String>()
            .where((creator) => creator.trim().isNotEmpty)
            .toList() ??
        [];
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

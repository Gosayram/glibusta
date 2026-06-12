import '../data/parsers/normalized_book.dart';
import 'epub_models.dart' as epub;

/// Bridges the new EPUB engine models to the existing NormalizedBook model.
///
/// This allows the new CustomEpubParser to work with the existing reader
/// infrastructure (BookOpenService, cache, controller, rendering) without
/// breaking the data flow.
class EpubBookAdapter {
  NormalizedBook toNormalizedBook(epub.EpubBook book, String bookId) {
    return NormalizedBook(
      id: bookId,
      title: book.title,
      authors: book.authors,
      description: book.description,
      coverUrl: book.coverImagePath,
      chapters: [
        for (var i = 0; i < book.chapters.length; i++) _toChapter(book.chapters[i], i),
      ],
      metadata: {
        'language': book.language,
        'totalChapters': book.chapters.length,
        'isFixedLayout': book.isFixedLayout,
        'hasToc': book.toc != null && book.toc!.isNotEmpty,
        'tocCount': book.toc?.length ?? 0,
      },
    );
  }

  ReaderChapter _toChapter(epub.EpubChapter chapter, int index) {
    final blocks = <ReaderBlock>[];
    for (var i = 0; i < chapter.blocks.length; i++) {
      final block = chapter.blocks[i];
      if (block is epub.SectionBlock) {
        for (var j = 0; j < block.children.length; j++) {
          final child = _toBlock(block.children[j], j);
          if (child != null) blocks.add(child);
        }
      } else {
        final mapped = _toBlock(block, i);
        if (mapped != null) blocks.add(mapped);
      }
    }
    return ReaderChapter(
      index: index,
      title: chapter.title,
      blocks: blocks,
    );
  }

  ReaderBlock? _toBlock(epub.ReaderBlock block, int index) {
    return switch (block) {
      epub.PageBreakBlock() => null,
      epub.ParagraphBlock(:final spans) => ReaderBlock(
        index: index,
        text: spans.map((s) => s.text).join(),
      ),
      epub.HeadingBlock(:final text) => ReaderBlock(
        index: index,
        text: text,
        type: BlockType.heading,
      ),
      epub.ImageBlock(:final localPath, :final alt) => ReaderBlock(
        index: index,
        text: alt ?? '',
        type: BlockType.image,
        imageUrl: localPath,
      ),
      epub.ListBlock(:final ordered, :final items) => ReaderBlock(
        index: index,
        text: _formatList(ordered, items),
      ),
      epub.TableBlock(:final rows) => ReaderBlock(
        index: index,
        text: _formatTable(rows),
      ),
      epub.QuoteBlock(:final text) => ReaderBlock(
        index: index,
        text: text,
        type: BlockType.quote,
      ),
      epub.SeparatorBlock() => ReaderBlock(
        index: index,
        text: '',
        type: BlockType.separator,
      ),
      epub.SectionBlock() => null,
    };
  }

  String _formatList(bool ordered, List<String> items) {
    final buf = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      if (ordered) {
        buf.writeln('${i + 1}. ${items[i]}');
      } else {
        buf.writeln('• ${items[i]}');
      }
    }
    return buf.toString().trimRight();
  }

  String _formatTable(List<List<String>> rows) {
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(row.join(' | '));
    }
    return buf.toString().trimRight();
  }
}

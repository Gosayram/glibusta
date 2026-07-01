import '../data/parsers/normalized_book.dart';
import 'epub_models.dart' as epub;

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
        richSpans: _toRichSpans(spans),
      ),
      epub.HeadingBlock(:final text, :final level) => ReaderBlock(
        index: index,
        text: text,
        type: BlockType.heading,
        headingLevel: level,
      ),
      epub.ImageBlock(:final localPath, :final alt, :final caption) => ReaderBlock(
        index: index,
        text: alt ?? caption ?? '',
        type: BlockType.image,
        imageUrl: localPath,
        imageAlt: alt,
        imageCaption: caption,
      ),
      epub.ListBlock(:final ordered, :final items) => ReaderBlock(
        index: index,
        text: items.join('\n'),
        type: BlockType.list,
        ordered: ordered,
        listItems: items.map((item) => ReaderBlock(index: 0, text: item)).toList(),
      ),
      epub.TableBlock(:final rows) => ReaderBlock(
        index: index,
        text: rows.map((r) => r.join(' | ')).join('\n'),
        type: BlockType.table,
        tableRows: rows,
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

  List<RichSpan>? _toRichSpans(List<epub.TextSpan> spans) {
    final hasFormatting = spans.any(
      (s) => s.bold || s.italic || s.superscript || s.href != null,
    );
    if (!hasFormatting) return null;
    return spans
        .map(
          (s) => RichSpan(
            text: s.text,
            bold: s.bold,
            italic: s.italic,
            superscript: s.superscript,
            href: s.href,
          ),
        )
        .toList();
  }
}

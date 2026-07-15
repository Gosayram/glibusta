import 'dart:ui' show TextAlign;

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
        if (book.textDirection != null) 'textDirection': book.textDirection,
      },
    );
  }

  ReaderChapter _toChapter(epub.EpubChapter chapter, int index) {
    final styles = chapter.styles;

    ReaderBlock applyCss(epub.ReaderBlock block, int idx) {
      final mapped = _toBlock(block, idx);
      if (mapped == null) return ReaderBlock(index: idx, text: '');
      if (block is epub.ParagraphBlock) {
        final paragraphStyles = _paragraphStyles(block, styles);
        final indent = _parsePx(paragraphStyles['text-indent']);
        final fontSize = _parsePx(paragraphStyles['font-size']);
        final alignment = paragraphStyles['text-align'];
        final align = alignment != null
            ? (TextAlign.values.firstWhere(
                (e) => e.name == alignment,
                orElse: () => TextAlign.left,
              ))
            : null;
        if (indent == null && fontSize == null && align == null) return mapped;
        return ReaderBlock(
          index: mapped.index,
          text: mapped.text,
          type: mapped.type,
          richSpans: mapped.richSpans,
          textIndent: indent ?? mapped.textIndent,
          fontSize: fontSize ?? mapped.fontSize,
          textAlign: align,
        );
      }
      return mapped;
    }

    final blocks = <ReaderBlock>[];
    void appendBlock(epub.ReaderBlock block) {
      if (block is epub.SectionBlock) {
        for (final child in block.children) {
          appendBlock(child);
        }
        return;
      }
      final mapped = applyCss(block, blocks.length);
      if (mapped.text.isNotEmpty || mapped.imageUrl != null) blocks.add(mapped);
    }

    for (final block in chapter.blocks) {
      appendBlock(block);
    }
    return ReaderChapter(
      index: index,
      title: chapter.title,
      blocks: blocks,
      smilEntries: chapter.smilEntries,
    );
  }

  Map<String, String> _paragraphStyles(
    epub.ParagraphBlock block,
    List<epub.EpubCssRule>? styles,
  ) {
    final result = <String, String>{};
    final priorities = <String, int>{};
    for (var sourceOrder = 0; sourceOrder < (styles?.length ?? 0); sourceOrder++) {
      final rule = styles![sourceOrder];
      final specificity = _matchingParagraphSpecificity(rule.selector, block.cssClasses);
      if (specificity == null) continue;
      for (final entry in rule.properties.entries) {
        final priority = specificity * (styles.length + 1) + sourceOrder;
        if (priority >= (priorities[entry.key] ?? -1)) {
          result[entry.key] = entry.value;
          priorities[entry.key] = priority;
        }
      }
    }
    result.addAll(block.inlineStyles);
    return result;
  }

  int? _matchingParagraphSpecificity(String selector, List<String> cssClasses) {
    if (selector == 'p') return 1;
    if (selector.startsWith('p.')) {
      return cssClasses.contains(selector.substring(2)) ? 11 : null;
    }
    if (selector.startsWith('.')) {
      return cssClasses.contains(selector.substring(1)) ? 10 : null;
    }
    return null;
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

  /// MD-1.2: parse CSS px/em length to double. ponytail: only px and em.
  static double? _parsePx(String? val) {
    if (val == null) return null;
    final v = val.trim();
    if (v.endsWith('px')) return double.tryParse(v.substring(0, v.length - 2).trim());
    final unit = v.endsWith('rem')
        ? 'rem'
        : v.endsWith('em')
        ? 'em'
        : null;
    if (unit != null) {
      final n = double.tryParse(v.substring(0, v.length - unit.length).trim());
      return n != null ? n * 16.0 : null;
    }
    return double.tryParse(v);
  }

  List<RichSpan>? _toRichSpans(List<epub.TextSpan> spans) {
    final hasFormatting = spans.any(
      (s) => s.bold || s.italic || s.superscript || s.href != null || s.color != null,
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
            color: s.color,
          ),
        )
        .toList();
  }
}

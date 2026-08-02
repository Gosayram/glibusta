import 'parsers/normalized_book.dart';

/// Composable text transforms applied to parsed content before rendering.
class ContentTransformerPipeline {
  final List<ContentTransformer> _transformers;
  const ContentTransformerPipeline(this._transformers);

  NormalizedBook transform(NormalizedBook book) {
    var result = book;
    for (final t in _transformers) {
      result = t.transform(result);
    }
    return result;
  }
}

abstract class ContentTransformer {
  NormalizedBook transform(NormalizedBook book);
}

/// Remove blocks with empty text (no content, just whitespace).
class EmptyBlockFilterTransformer extends ContentTransformer {
  @override
  NormalizedBook transform(NormalizedBook book) => NormalizedBook(
    id: book.id,
    title: book.title,
    authors: book.authors,
    description: book.description,
    coverUrl: book.coverUrl,
    chapters: book.chapters
        .map(
          (ch) => ReaderChapter(
            index: ch.index,
            title: ch.title,
            smilEntries: ch.smilEntries,
            blocks: ch.blocks
                .where((b) => b.text.trim().isNotEmpty || b.type == BlockType.image)
                .toList(),
          ),
        )
        .toList(),
    metadata: book.metadata,
    fonts: book.fonts,
  );
}

/// Collapse multiple whitespace characters into single spaces.
/// Preserves single newlines but collapses multiple blank lines.
class WhitespaceCollapsingTransformer extends ContentTransformer {
  static final _multiSpace = RegExp(r'[^\S\n]+');
  static final _multiNewline = RegExp(r'\n{2,}');

  @override
  NormalizedBook transform(NormalizedBook book) => NormalizedBook(
    id: book.id,
    title: book.title,
    authors: book.authors,
    description: book.description,
    coverUrl: book.coverUrl,
    chapters: book.chapters
        .map(
          (ch) => ReaderChapter(
            index: ch.index,
            title: ch.title,
            smilEntries: ch.smilEntries,
            blocks: ch.blocks.map(_transformBlock).toList(),
          ),
        )
        .toList(),
    metadata: book.metadata,
    fonts: book.fonts,
  );

  ReaderBlock _transformBlock(ReaderBlock b) {
    if (b.type == BlockType.image || b.type == BlockType.separator) return b;
    final cleaned = _collapse(b.text);
    if (cleaned == b.text) return b;
    return ReaderBlock(
      index: b.index,
      text: cleaned,
      type: b.type,
      imageUrl: b.imageUrl,
      noteRef: b.noteRef,
      richSpans: b.richSpans,
      headingLevel: b.headingLevel,
      ordered: b.ordered,
      listItems: b.listItems,
      tableRows: b.tableRows,
      imageAlt: b.imageAlt,
      imageCaption: b.imageCaption,
      textIndent: b.textIndent,
      fontSize: b.fontSize,
      textAlign: b.textAlign,
      noteId: b.noteId,
      whiteSpaceMode: b.whiteSpaceMode,
      pageBreakBefore: b.pageBreakBefore,
      pageBreakInsideAvoid: b.pageBreakInsideAvoid,
      hasDropCap: b.hasDropCap,
      rawCssProps: b.rawCssProps,
    );
  }

  String _collapse(String text) {
    var s = text.replaceAll(_multiSpace, ' ');
    s = s.replaceAll(_multiNewline, '\n');
    return s.trim();
  }
}

/// Extract CSS color from rawCssProps pipe-separated field and populate
/// the `color` field on RichSpans that don't already have one.
class RichSpanColorTransformer extends ContentTransformer {
  @override
  NormalizedBook transform(NormalizedBook book) => NormalizedBook(
    id: book.id,
    title: book.title,
    authors: book.authors,
    description: book.description,
    coverUrl: book.coverUrl,
    chapters: book.chapters
        .map(
          (ch) => ReaderChapter(
            index: ch.index,
            title: ch.title,
            smilEntries: ch.smilEntries,
            blocks: ch.blocks.map(_transformBlock).toList(),
          ),
        )
        .toList(),
    metadata: book.metadata,
    fonts: book.fonts,
  );

  ReaderBlock _transformBlock(ReaderBlock b) {
    if (b.richSpans == null || b.richSpans!.isEmpty) return b;
    if (b.rawCssProps == null) return b;
    final color = _extractFgColor(b.rawCssProps!);
    if (color == null) return b;
    final updatedSpans = b.richSpans!.map((span) {
      if (span.color != null) return span;
      return RichSpan(
        text: span.text,
        bold: span.bold,
        italic: span.italic,
        superscript: span.superscript,
        subscript: span.subscript,
        strikethrough: span.strikethrough,
        code: span.code,
        styleName: span.styleName,
        lineBreak: span.lineBreak,
        href: span.href,
        color: color,
      );
    }).toList();
    return ReaderBlock(
      index: b.index,
      text: b.text,
      type: b.type,
      imageUrl: b.imageUrl,
      noteRef: b.noteRef,
      richSpans: updatedSpans,
      headingLevel: b.headingLevel,
      ordered: b.ordered,
      listItems: b.listItems,
      tableRows: b.tableRows,
      imageAlt: b.imageAlt,
      imageCaption: b.imageCaption,
      textIndent: b.textIndent,
      fontSize: b.fontSize,
      textAlign: b.textAlign,
      noteId: b.noteId,
      whiteSpaceMode: b.whiteSpaceMode,
      pageBreakBefore: b.pageBreakBefore,
      pageBreakInsideAvoid: b.pageBreakInsideAvoid,
      hasDropCap: b.hasDropCap,
      rawCssProps: b.rawCssProps,
    );
  }

  static final _fgPrefix = RegExp(r'^fg:(.+)$');

  String? _extractFgColor(String raw) {
    for (final part in raw.split('|')) {
      final m = _fgPrefix.firstMatch(part);
      if (m != null) return m.group(1);
    }
    return null;
  }
}

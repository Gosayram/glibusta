import 'package:flutter/material.dart' show TextAlign;

class NormalizedBook {
  final String id;
  final String title;
  final List<String> authors;
  final String? description;
  final String? coverUrl;
  final List<ReaderChapter> chapters;
  final Map<String, dynamic>? metadata;

  const NormalizedBook({
    required this.id,
    required this.title,
    required this.authors,
    this.description,
    this.coverUrl,
    this.chapters = const [],
    this.metadata,
  });

  NormalizedBookMetadata toMetadata() => NormalizedBookMetadata(
    id: id,
    title: title,
    authors: authors,
    description: description,
    coverUrl: coverUrl,
    chapterCount: chapters.length,
    chapterTitles: chapters.map((c) => c.title).toList(),
    metadata: metadata,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'description': description,
    'coverUrl': coverUrl,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'metadata': metadata,
  };

  factory NormalizedBook.fromJson(Map<String, dynamic> json) => NormalizedBook(
    id: json['id'] as String,
    title: json['title'] as String,
    authors: (json['authors'] as List<String>?) ?? [],
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    chapters:
        (json['chapters'] as List<dynamic>?)
            ?.map((c) => ReaderChapter.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  NormalizedBook withCleanedBlocks() {
    return NormalizedBook(
      id: id,
      title: title,
      authors: authors,
      description: description,
      coverUrl: coverUrl,
      chapters: chapters.map((ch) => ch.withCleanedBlocks()).toList(),
      metadata: metadata,
    );
  }
}

class NormalizedBookMetadata {
  final String id;
  final String title;
  final List<String> authors;
  final String? description;
  final String? coverUrl;
  final int chapterCount;
  final List<String> chapterTitles;
  final Map<String, dynamic>? metadata;

  const NormalizedBookMetadata({
    required this.id,
    required this.title,
    required this.authors,
    this.description,
    this.coverUrl,
    required this.chapterCount,
    required this.chapterTitles,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'description': description,
    'coverUrl': coverUrl,
    'chapterCount': chapterCount,
    'chapterTitles': chapterTitles,
    'metadata': metadata,
  };

  factory NormalizedBookMetadata.fromJson(Map<String, dynamic> json) => NormalizedBookMetadata(
    id: json['id'] as String,
    title: json['title'] as String,
    authors: (json['authors'] as List<String>?) ?? [],
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    chapterCount: json['chapterCount'] as int,
    chapterTitles: (json['chapterTitles'] as List<dynamic>?)?.cast<String>() ?? [],
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

class ReaderChapter {
  final int index;
  final String title;
  final List<ReaderBlock> blocks;

  const ReaderChapter({
    required this.index,
    required this.title,
    required this.blocks,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory ReaderChapter.fromJson(Map<String, dynamic> json) => ReaderChapter(
    index: json['index'] as int,
    title: json['title'] as String,
    blocks:
        (json['blocks'] as List<dynamic>?)
            ?.map((b) => ReaderBlock.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [],
  );

  static final _pageNumberRegExp = RegExp(
    r'^[\[\(\-—–]\s*\d+\s*[\]\)\-—–]$',
  );

  static bool _looksLikePageNumber(String text) {
    if (text.length > 10) return false;
    return _pageNumberRegExp.hasMatch(text);
  }

  ReaderChapter withCleanedBlocks() {
    final cleaned = <ReaderBlock>[];
    for (final block in blocks) {
      if (block.type == BlockType.paragraph && block.text.trim().isEmpty) {
        continue;
      }
      if (block.type == BlockType.paragraph && _looksLikePageNumber(block.text.trim())) {
        continue;
      }
      cleaned.add(block);
    }
    return ReaderChapter(index: index, title: title, blocks: cleaned);
  }
}

class ReaderBlock {
  final int index;
  final String text;
  final BlockType type;
  final String? imageUrl;
  final String? noteRef;
  final List<RichSpan>? richSpans;
  final int? headingLevel;
  final bool? ordered;
  final List<ReaderBlock>? listItems;
  final List<List<String>>? tableRows;
  final String? imageAlt;
  final String? imageCaption;
  final double? textIndent;
  final TextAlign? textAlign;
  final String? noteId;
  final String? whiteSpaceMode; // MD-1.7: 'pre', 'pre-wrap', 'nowrap'

  const ReaderBlock({
    required this.index,
    required this.text,
    this.type = BlockType.paragraph,
    this.imageUrl,
    this.noteRef,
    this.richSpans,
    this.headingLevel,
    this.ordered,
    this.listItems,
    this.tableRows,
    this.imageAlt,
    this.imageCaption,
    this.textIndent,
    this.textAlign,
    this.noteId,
    this.whiteSpaceMode,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'type': type.name,
    'imageUrl': imageUrl,
    'noteRef': noteRef,
    if (richSpans != null && richSpans!.isNotEmpty)
      'richSpans': richSpans!.map((s) => s.toJson()).toList(),
    if (headingLevel != null) 'headingLevel': headingLevel,
    if (ordered != null) 'ordered': ordered,
    if (listItems != null && listItems!.isNotEmpty)
      'listItems': listItems!.map((b) => b.toJson()).toList(),
    if (tableRows != null && tableRows!.isNotEmpty) 'tableRows': tableRows,
    if (imageAlt != null) 'imageAlt': imageAlt,
    if (imageCaption != null) 'imageCaption': imageCaption,
    if (textIndent != null) 'textIndent': textIndent,
    if (textAlign != null || whiteSpaceMode != null)
      'textAlign': [
        if (textAlign != null) textAlign!.name,
        if (whiteSpaceMode != null) 'ws:$whiteSpaceMode',
      ].join('|'),
    if (noteId != null) 'noteId': noteId,
  };

  // CRT-21.1: normalize whitespace before typography processing
  static String _normalizeWhitespace(String text) {
    final cleaned = text.replaceAll('\r\n', ' ').replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    // Collapse 2+ consecutive spaces into one
    final sb = StringBuffer();
    var prevSpace = false;
    for (var i = 0; i < cleaned.length; i++) {
      final c = cleaned[i];
      if (c == ' ' || c == '\t' || c == '\u{00A0}') {
        if (!prevSpace) {
          sb.write(c);
          prevSpace = true;
        }
      } else {
        sb.write(c);
        prevSpace = false;
      }
    }
    return sb.toString();
  }

  // HG-1.1: replace spaces with NBSP after initials, between digits, after short words
  // ponytail: char-level scan, no regex. Runs once per block at load time.
  static String _applyNonBreakingSpaces(String text) {
    // Fast path: skip short strings
    if (text.length < 3) return text;

    final chars = text.split('');
    final len = chars.length;
    final result = StringBuffer();

    for (var i = 0; i < len; i++) {
      if (chars[i] == ' ' && i > 0 && i + 1 < len) {
        final prev = chars[i - 1];
        final next = chars[i + 1];

        // After period (initial): "А." or "A."
        if (prev == '.') {
          result.write('\u{00A0}');
          continue;
        }

        // Between digit groups: "100 000"
        if (_isDigit(prev) && _isDigit(next)) {
          result.write('\u{00A0}');
          continue;
        }

        // After single letter (preposition)
        var wordStart = i - 1;
        while (wordStart > 0 && _isLetter(chars[wordStart - 1])) {
          wordStart--;
        }
        final wordLen = (i - 1) - wordStart;
        if (wordLen == 0 && _isLetter(prev)) {
          result.write('\u{00A0}');
          continue;
        }

        // Before short word (1-2 letters)
        var nextWordEnd = i + 1;
        while (nextWordEnd < len && _isLetter(chars[nextWordEnd])) {
          nextWordEnd++;
        }
        final nextWordLen = nextWordEnd - (i + 1);
        if (nextWordLen <= 2) {
          result.write('\u{00A0}');
          continue;
        }
      }
      result.write(chars[i]);
    }
    // HG-1.5: protect against orphan word on last line (>=8 words → NBSP between last two)
    final out = result.toString();
    var sc = 0;
    for (var i = 0; i < out.length; i++) {
      if (out[i] == ' ') sc++;
    }
    if (sc >= 7) {
      final ls = out.lastIndexOf(' ');
      if (ls > 0) {
        return '${out.substring(0, ls)}\u{00A0}${out.substring(ls + 1)}';
      }
    }
    return out;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  static bool _isLetter(String c) {
    final code = c.codeUnitAt(0);
    // ASCII letters + Cyrillic ranges
    return (code >= 0x41 && code <= 0x5A) || // A-Z
        (code >= 0x61 && code <= 0x7A) || // a-z
        (code >= 0xC0 && code <= 0xFF) || // А-я (partial, covers most Cyrillic in single code unit)
        (code >= 0x100); // Extended Unicode (covers remaining Cyrillic + others)
    // ponytail: conservative letter detection, may match some non-letter chars
  }

  factory ReaderBlock.fromJson(Map<String, dynamic> json) => ReaderBlock(
    index: json['index'] as int,
    text: _applyNonBreakingSpaces(_normalizeWhitespace(json['text'] as String)),
    type: BlockType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => BlockType.paragraph,
    ),
    imageUrl: json['imageUrl'] as String?,
    noteRef: json['noteRef'] as String?,
    richSpans: (json['richSpans'] as List<dynamic>?)
        ?.map((s) => RichSpan.fromJson(s as Map<String, dynamic>))
        .toList(),
    headingLevel: json['headingLevel'] as int?,
    ordered: json['ordered'] as bool?,
    listItems: (json['listItems'] as List<dynamic>?)
        ?.map((b) => ReaderBlock.fromJson(b as Map<String, dynamic>))
        .toList(),
    tableRows: (json['tableRows'] as List<dynamic>?)
        ?.map((row) => (row as List<dynamic>).cast<String>())
        .toList(),
    imageAlt: json['imageAlt'] as String?,
    imageCaption: json['imageCaption'] as String?,
    textIndent: (json['textIndent'] as num?)?.toDouble(),
    textAlign: _parseTextAlign(json['textAlign']),
    noteId: json['noteId'] as String?,
    whiteSpaceMode: _parseWhiteSpaceMode(json['textAlign']),
  );
}

// Parse pipe-separated CSS properties from text_align field.
// Format: "left|ws:pre|fg:#333|lh:1.5|fw:700|fs:italic|bg:#fff"
List<String> _splitCssProps(String raw) => raw.split('|');

String? _extractProp(String rawData, String prefix) {
  for (final part in _splitCssProps(rawData)) {
    if (part.startsWith('$prefix:')) return part.substring(prefix.length + 1);
  }
  return null;
}

// MD-1.7: extract white-space mode from raw text_align value
String? _parseWhiteSpaceMode(dynamic raw) {
  if (raw is! String) return null;
  return _extractProp(raw, 'ws');
}

TextAlign? _parseTextAlign(dynamic raw) {
  if (raw == null) return null;
  final r = raw as String;
  // Check for pipe-separated format first
  if (r.contains('|')) {
    for (final part in _splitCssProps(r)) {
      if (!part.contains(':')) {
        return TextAlign.values.firstWhere(
          (e) => e.name == part,
          orElse: () => TextAlign.left,
        );
      }
    }
    return null;
  }
  // Simple format: just a name or ws: prefix
  if (r.startsWith('ws:')) return null;
  return TextAlign.values.firstWhere(
    (e) => e.name == r,
    orElse: () => TextAlign.left,
  );
}

/// Extract CSS color (fg: prefix) from raw text_align value.
String? parseCssColor(dynamic raw) {
  if (raw is! String) return null;
  return _extractProp(raw, 'fg');
}

/// Extract CSS background-color (bg: prefix) from raw text_align value.
String? parseCssBgColor(dynamic raw) {
  if (raw is! String) return null;
  return _extractProp(raw, 'bg');
}

/// Extract CSS line-height (lh: prefix) from raw text_align value.
double? parseCssLineHeight(dynamic raw) {
  if (raw is! String) return null;
  final v = _extractProp(raw, 'lh');
  if (v == null) return null;
  return double.tryParse(v);
}

/// Extract CSS font-weight (fw: prefix) from raw text_align value.
int? parseCssFontWeight(dynamic raw) {
  if (raw is! String) return null;
  final v = _extractProp(raw, 'fw');
  if (v == null) return null;
  return int.tryParse(v);
}

/// Signature for a block transformer hook.
/// Plugins can register transformers to modify blocks before rendering.
/// Return null to skip the block entirely, or a modified/new block.
typedef BlockTransformer = ReaderBlock? Function(ReaderBlock block);

class RichSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool superscript;
  final bool lineBreak;
  final String? href;
  final String? color;

  const RichSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.superscript = false,
    this.lineBreak = false,
    this.href,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (superscript) 'superscript': true,
    if (lineBreak) 'lineBreak': true,
    if (href != null) 'href': href,
    if (color != null) 'color': color,
  };

  factory RichSpan.fromJson(Map<String, dynamic> json) => RichSpan(
    text: json['text'] as String,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    superscript: json['superscript'] as bool? ?? false,
    lineBreak: json['lineBreak'] as bool? ?? false,
    href: json['href'] as String?,
    color: json['color'] as String?,
  );
}

enum BlockType {
  paragraph,
  heading,
  image,
  quote,
  footnote,
  separator,
  table,
  list,
  epigraph,
  poem,
  cite,
  textAuthor,
  subtitle,
}

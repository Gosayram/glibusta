import 'dart:typed_data';

import 'package:flutter/material.dart' show TextAlign;

import 'smil_parser.dart';

class NormalizedBook {
  final String id;
  final String title;
  final List<String> authors;
  final String? description;
  final String? coverUrl;
  final List<ReaderChapter> chapters;
  final Map<String, dynamic>? metadata;
  final Map<String, Uint8List> fonts;

  const NormalizedBook({
    required this.id,
    required this.title,
    required this.authors,
    this.description,
    this.coverUrl,
    this.chapters = const [],
    this.metadata,
    this.fonts = const {},
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
    fonts: fonts,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'description': description,
    'coverUrl': coverUrl,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'metadata': metadata,
    if (fonts.isNotEmpty) 'fonts': fonts.map((k, v) => MapEntry(k, v)),
  };

  factory NormalizedBook.fromJson(Map<String, dynamic> json) => NormalizedBook(
    id: json['id'] as String,
    title: json['title'] as String,
    authors: (json['authors'] as List<dynamic>?)?.cast<String>() ?? const [],
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    chapters:
        (json['chapters'] as List<dynamic>?)
            ?.map((c) => ReaderChapter.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
    metadata: json['metadata'] as Map<String, dynamic>?,
    fonts:
        (json['fonts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Uint8List)) ??
        const {},
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
      fonts: fonts,
    );
  }

  NormalizedBook withResolvedImageUrls(Map<String, String> urls) {
    if (urls.isEmpty) return this;
    return NormalizedBook(
      id: id,
      title: title,
      authors: authors,
      description: description,
      coverUrl: coverUrl,
      chapters: chapters
          .map(
            (chapter) => ReaderChapter(
              index: chapter.index,
              title: chapter.title,
              smilEntries: chapter.smilEntries,
              blocks: chapter.blocks
                  .map(
                    (block) => switch (urls[block.imageUrl]) {
                      final String url => block.withImageUrl(url),
                      _ => block,
                    },
                  )
                  .toList(),
            ),
          )
          .toList(),
      metadata: metadata,
      fonts: fonts,
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
  final Map<String, Uint8List> fonts;

  const NormalizedBookMetadata({
    required this.id,
    required this.title,
    required this.authors,
    this.description,
    this.coverUrl,
    required this.chapterCount,
    required this.chapterTitles,
    this.metadata,
    this.fonts = const {},
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
    if (fonts.isNotEmpty) 'fonts': fonts.map((k, v) => MapEntry(k, v)),
  };

  factory NormalizedBookMetadata.fromJson(Map<String, dynamic> json) => NormalizedBookMetadata(
    id: json['id'] as String,
    title: json['title'] as String,
    authors: (json['authors'] as List<dynamic>?)?.cast<String>() ?? const [],
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    chapterCount: json['chapterCount'] as int,
    chapterTitles: (json['chapterTitles'] as List<dynamic>?)?.cast<String>() ?? [],
    metadata: json['metadata'] as Map<String, dynamic>?,
    fonts:
        (json['fonts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Uint8List)) ??
        const {},
  );

  /// Builds a chapter list from metadata, preferring [loadedChapters] when
  /// available and falling back to empty blocks with title-derived names.
  List<ReaderChapter> buildChapters([Map<int, ReaderChapter>? loadedChapters]) {
    return List.generate(chapterCount, (i) {
      final loaded = loadedChapters?[i];
      if (loaded != null) return loaded;
      return ReaderChapter(
        index: i,
        title: i < chapterTitles.length ? chapterTitles[i] : 'Глава ${i + 1}',
        blocks: const [],
      );
    });
  }
}

class ReaderChapter {
  final int index;
  final String title;
  final List<ReaderBlock> blocks;
  final List<SmilEntry>? smilEntries;

  const ReaderChapter({
    required this.index,
    required this.title,
    required this.blocks,
    this.smilEntries,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    if (smilEntries != null && smilEntries!.isNotEmpty)
      'smil': smilEntries!
          .map(
            (e) => {
              'textRef': e.textRef,
              if (e.paragraphId != null) 'paragraphId': e.paragraphId,
              'audioSrc': e.audioSrc,
              'clipBeginMs': e.clipBegin.inMilliseconds,
              'clipEndMs': e.clipEnd.inMilliseconds,
            },
          )
          .toList(),
  };

  factory ReaderChapter.fromJson(Map<String, dynamic> json) => ReaderChapter(
    index: json['index'] as int,
    title: json['title'] as String,
    blocks:
        (json['blocks'] as List<dynamic>?)
            ?.map((b) => ReaderBlock.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [],
    smilEntries: (json['smil'] as List<dynamic>?)?.map((s) {
      final m = s as Map<String, dynamic>;
      return SmilEntry(
        textRef: m['textRef'] as String,
        paragraphId: m['paragraphId'] as String?,
        audioSrc: m['audioSrc'] as String,
        clipBegin: Duration(milliseconds: (m['clipBeginMs'] as num).toInt()),
        clipEnd: Duration(milliseconds: (m['clipEndMs'] as num).toInt()),
      );
    }).toList(),
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
    return ReaderChapter(
      index: index,
      title: _normalizedTitle(cleaned),
      blocks: cleaned,
      smilEntries: smilEntries,
    );
  }

  /// Repairs malformed source metadata that appends a chapter's first
  /// paragraph to its heading. The rendered blocks remain the source of truth:
  /// only discard the suffix when it demonstrably duplicates the paragraph
  /// immediately following the first heading.
  String _normalizedTitle(List<ReaderBlock> cleaned) {
    final titleText = title.trim();
    final headingIndex = cleaned.indexWhere((block) => block.type == BlockType.heading);
    if (titleText.isEmpty || headingIndex < 0) return titleText;

    final heading = cleaned[headingIndex].text.trim();
    final paragraph = cleaned
        .skip(headingIndex + 1)
        .firstWhere(
          (block) => block.type == BlockType.paragraph && block.text.trim().isNotEmpty,
          orElse: () => const ReaderBlock(index: -1, text: ''),
        );
    final normalizedTitle = _collapseWhitespace(titleText);
    final normalizedHeading = _collapseWhitespace(heading);
    final normalizedParagraph = _collapseWhitespace(paragraph.text);
    if (normalizedHeading.isEmpty || normalizedParagraph.isEmpty) return titleText;
    if (!normalizedTitle.startsWith(normalizedHeading)) return titleText;

    final suffix = normalizedTitle.substring(normalizedHeading.length).trimLeft();
    final comparableSuffix = suffix.replaceFirst(RegExp(r'(?:\.\.\.|…)+$'), '').trimRight();
    if (comparableSuffix.length < 24 || !normalizedParagraph.startsWith(comparableSuffix)) {
      return titleText;
    }
    return heading;
  }

  static String _collapseWhitespace(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
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
  final double? fontSize;
  final TextAlign? textAlign;
  final String? noteId;
  final String? whiteSpaceMode; // MD-1.7: 'pre', 'pre-wrap', 'nowrap'
  final bool pageBreakBefore;
  final bool pageBreakInsideAvoid;
  final bool hasDropCap;
  final String? rawCssProps;

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
    this.fontSize,
    this.textAlign,
    this.noteId,
    this.whiteSpaceMode,
    this.pageBreakBefore = false,
    this.pageBreakInsideAvoid = false,
    this.hasDropCap = false,
    this.rawCssProps,
  });

  ReaderBlock withImageUrl(String value) => ReaderBlock(
    index: index,
    text: text,
    type: type,
    imageUrl: value,
    noteRef: noteRef,
    richSpans: richSpans,
    headingLevel: headingLevel,
    ordered: ordered,
    listItems: listItems,
    tableRows: tableRows,
    imageAlt: imageAlt,
    imageCaption: imageCaption,
    textIndent: textIndent,
    fontSize: fontSize,
    textAlign: textAlign,
    noteId: noteId,
    whiteSpaceMode: whiteSpaceMode,
    pageBreakBefore: pageBreakBefore,
    pageBreakInsideAvoid: pageBreakInsideAvoid,
    hasDropCap: hasDropCap,
    rawCssProps: rawCssProps,
  );

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
    if (fontSize != null) 'fontSize': fontSize,
    if (textAlign != null || whiteSpaceMode != null)
      'textAlign': [
        if (textAlign != null) textAlign!.name,
        if (whiteSpaceMode != null) 'ws:$whiteSpaceMode',
      ].join('|'),
    if (noteId != null) 'noteId': noteId,
    if (pageBreakBefore) 'pageBreakBefore': true,
    if (pageBreakInsideAvoid) 'pageBreakInsideAvoid': true,
    if (hasDropCap) 'hasDropCap': true,
    if (rawCssProps != null) 'rawCssProps': rawCssProps,
  };

  factory ReaderBlock.fromJson(Map<String, dynamic> json) => ReaderBlock(
    index: json['index'] as int,
    text: json['text'] as String,
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
    fontSize: (json['fontSize'] as num?)?.toDouble(),
    textAlign: _parseTextAlign(json['textAlign']),
    noteId: json['noteId'] as String?,
    whiteSpaceMode: _parseWhiteSpaceMode(json['textAlign']),
    pageBreakBefore: json['pageBreakBefore'] as bool? ?? false,
    pageBreakInsideAvoid: json['pageBreakInsideAvoid'] as bool? ?? false,
    hasDropCap: json['hasDropCap'] as bool? ?? false,
    rawCssProps: json['rawCssProps'] as String?,
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
  final bool subscript;
  final bool strikethrough;
  final bool code;
  final String? styleName;
  final bool lineBreak;
  final String? href;
  final String? color;

  const RichSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.superscript = false,
    this.subscript = false,
    this.strikethrough = false,
    this.code = false,
    this.styleName,
    this.lineBreak = false,
    this.href,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (superscript) 'superscript': true,
    if (subscript) 'subscript': true,
    if (strikethrough) 'strikethrough': true,
    if (code) 'code': true,
    if (styleName != null) 'styleName': styleName,
    if (lineBreak) 'lineBreak': true,
    if (href != null) 'href': href,
    if (color != null) 'color': color,
  };

  factory RichSpan.fromJson(Map<String, dynamic> json) => RichSpan(
    text: json['text'] as String,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    superscript: json['superscript'] as bool? ?? false,
    subscript: json['subscript'] as bool? ?? false,
    strikethrough: json['strikethrough'] as bool? ?? false,
    code: json['code'] as bool? ?? false,
    styleName: json['styleName'] as String?,
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
  listItem,
  preformatted,
}

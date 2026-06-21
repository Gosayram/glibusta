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
  final double? textIndent;
  final TextAlign? textAlign;
  final String? noteId;

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
    this.textIndent,
    this.textAlign,
    this.noteId,
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
    if (tableRows != null && tableRows!.isNotEmpty)
      'tableRows': tableRows,
    if (imageAlt != null) 'imageAlt': imageAlt,
    if (textIndent != null) 'textIndent': textIndent,
    if (textAlign != null) 'textAlign': textAlign!.name,
    if (noteId != null) 'noteId': noteId,
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
    textIndent: (json['textIndent'] as num?)?.toDouble(),
    textAlign: json['textAlign'] != null
        ? TextAlign.values.firstWhere(
            (e) => e.name == json['textAlign'],
            orElse: () => TextAlign.left,
          )
        : null,
    noteId: json['noteId'] as String?,
  );
}

class RichSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool superscript;
  final bool lineBreak;
  final String? href;

  const RichSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.superscript = false,
    this.lineBreak = false,
    this.href,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (superscript) 'superscript': true,
    if (lineBreak) 'lineBreak': true,
    if (href != null) 'href': href,
  };

  factory RichSpan.fromJson(Map<String, dynamic> json) => RichSpan(
    text: json['text'] as String,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    superscript: json['superscript'] as bool? ?? false,
    lineBreak: json['lineBreak'] as bool? ?? false,
    href: json['href'] as String?,
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

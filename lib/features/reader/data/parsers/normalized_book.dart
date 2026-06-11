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

  const ReaderBlock({
    required this.index,
    required this.text,
    this.type = BlockType.paragraph,
    this.imageUrl,
    this.noteRef,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'type': type.name,
    'imageUrl': imageUrl,
    'noteRef': noteRef,
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
  );
}

enum BlockType {
  paragraph,
  heading,
  image,
  quote,
  footnote,
  separator,
}

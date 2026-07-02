enum EpubResourceType { xhtml, css, image, nav, ncx, font, unknown }

final class EpubBook {
  const EpubBook({
    required this.title,
    required this.authors,
    this.language,
    this.description,
    required this.chapters,
    required this.resources,
    this.toc,
    this.coverImagePath,
    this.isFixedLayout = false,
  });
  final String title;
  final List<String> authors;
  final String? language;
  final String? description;
  final List<EpubChapter> chapters;
  final Map<String, EpubResource> resources;
  final List<TocItem>? toc;
  final String? coverImagePath;
  final bool isFixedLayout;
}

final class EpubChapter {
  const EpubChapter({
    required this.id,
    required this.href,
    required this.title,
    required this.blocks,
    this.linear = true,
    this.styles,
  });
  final String id;
  final String href;
  final String title;
  final List<ReaderBlock> blocks;
  final bool linear;

  /// CSS rules extracted from chapter's <style> tags.
  /// Key: selector ("p", ".poem", "p.poem"), Value: property map.
  final Map<String, Map<String, String>>? styles;
}

sealed class ReaderBlock {
  const ReaderBlock();
}

final class ParagraphBlock extends ReaderBlock {
  const ParagraphBlock(this.spans);
  final List<TextSpan> spans;
}

final class HeadingBlock extends ReaderBlock {
  const HeadingBlock(this.text, this.level);
  final String text;
  final int level;
}

final class ImageBlock extends ReaderBlock {
  const ImageBlock({
    required this.resourceId,
    required this.localPath,
    this.alt,
    this.caption,
  });
  final String resourceId;
  final String localPath;
  final String? alt;
  final String? caption;
}

final class ListBlock extends ReaderBlock {
  const ListBlock({required this.ordered, required this.items});
  final bool ordered;
  final List<String> items;
}

final class TableBlock extends ReaderBlock {
  const TableBlock(this.rows);
  final List<List<String>> rows;
}

final class QuoteBlock extends ReaderBlock {
  const QuoteBlock(this.text);
  final String text;
}

final class SeparatorBlock extends ReaderBlock {
  const SeparatorBlock();
}

final class PageBreakBlock extends ReaderBlock {
  const PageBreakBlock({required this.label});
  final String label;
}

final class SectionBlock extends ReaderBlock {
  const SectionBlock(this.children);
  final List<ReaderBlock> children;
}

final class TextSpan {
  const TextSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.superscript = false,
    this.href,
    this.color,
  });
  final String text;
  final bool bold;
  final bool italic;
  final bool superscript;
  final String? href;
  final String? color;
}

final class EpubResource {
  const EpubResource({
    required this.id,
    required this.href,
    required this.fullPath,
    required this.mediaType,
    required this.properties,
    required this.type,
  });
  final String id;
  final String href;
  final String fullPath;
  final String mediaType;
  final Set<String> properties;
  final EpubResourceType type;
  bool get isNav => properties.contains('nav');
  bool get isCoverImage => properties.contains('cover-image');
}

final class TocItem {
  const TocItem({
    required this.title,
    required this.href,
    this.children = const [],
  });
  final String title;
  final String href;
  final List<TocItem> children;
}

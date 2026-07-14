import 'dart:typed_data';
import 'dart:ui' show TextAlign;

import '../../../../core/errors/failures.dart';
import '../../../../src/rust/api/api/api.dart' as rust_api;
import '../../../../src/rust/api/api/models.dart' as rust_models;
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart' as local;

class RustBookParser implements BookParser {
  static final RustBookParser _instance = RustBookParser._();
  factory RustBookParser() => _instance;
  RustBookParser._();

  @override
  bool supports(BookFormat format) => switch (format) {
    BookFormat.fb2 ||
    BookFormat.epub ||
    BookFormat.txt ||
    BookFormat.docx ||
    BookFormat.rtf ||
    BookFormat.mobi ||
    BookFormat.azw3 ||
    BookFormat.prc => true,
    _ => false,
  };

  String _formatName(BookFormat format) => switch (format) {
    BookFormat.fb2 => 'fb2',
    BookFormat.epub => 'epub',
    BookFormat.txt => 'txt',
    BookFormat.docx => 'docx',
    BookFormat.rtf => 'rtf',
    BookFormat.mobi || BookFormat.azw3 || BookFormat.prc => 'mobi',
    _ => throw UnsupportedError('Unsupported format: $format'),
  };

  @override
  Future<local.NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    if (fileName == null) {
      throw const ParserFailure('fileName is required to detect format');
    }
    final format = detectBookFormat(fileName);
    if (!supports(format)) {
      throw UnsupportedError('Rust parser does not support $format');
    }

    try {
      final book = await rust_api.parseBookLegacy(
        bytes: bytes,
        format: _formatName(format),
        forcedEncoding: forcedEncoding,
      );
      return _toNormalizedBook(book);
    } on Object catch (e) {
      throw ParserFailure('Rust parser failed for $format: $e');
    }
  }

  @override
  Future<local.NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  }) async {
    try {
      final book = await rust_api.parseBook(path: filePath);
      return _toNormalizedBook(book);
    } on Object catch (e) {
      throw ParserFailure('Rust parser failed for $filePath: $e');
    }
  }

  Future<local.NormalizedBookMetadata?> parseMetadata(
    Uint8List bytes, {
    String? fileName,
  }) async {
    try {
      final book = await parse(bytes, fileName: fileName);
      return book.toMetadata();
    } on Object catch (_) {
      return null;
    }
  }

  static local.NormalizedBook _toNormalizedBook(rust_models.NormalizedBook r) {
    return local.NormalizedBook(
      id: r.id,
      title: r.title,
      authors: r.authors,
      description: r.description,
      coverUrl: r.coverUrl,
      chapters: r.chapters
          .map(
            (rc) => local.ReaderChapter(
              index: rc.index,
              title: rc.title,
              blocks: rc.blocks
                  .map(
                    (rb) => local.ReaderBlock(
                      index: rb.index,
                      text: rb.text,
                      type: _toBlockType(rb.blockType),
                      imageUrl: rb.imageUrl,
                      noteRef: rb.noteRef,
                      richSpans: rb.richSpans
                          ?.map(
                            (rust_models.RichSpan rs) => local.RichSpan(
                              text: rs.text,
                              bold: rs.bold,
                              italic: rs.italic,
                              superscript: rs.superscript,
                              href: rs.href,
                              lineBreak: rs.lineBreak,
                            ),
                          )
                          .toList(),
                      headingLevel: rb.headingLevel,
                      ordered: rb.ordered,
                      listItems: rb.listItems
                          ?.map(
                            (item) => local.ReaderBlock(
                              index: item.index,
                              text: item.text,
                              type: _toBlockType(item.blockType),
                            ),
                          )
                          .toList(),
                      tableRows: rb.tableRows?.map((row) => row.cast<String>()).toList(),
                      imageAlt: rb.imageAlt,
                      textIndent: rb.textIndent,
                      textAlign: _parseTextAlignFromRust(rb.textAlign),
                      whiteSpaceMode: _extractProp(rb.textAlign, 'ws'),
                      noteId: rb.noteId,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  /// Extract a pipe-separated CSS property from the raw text_align value.
  /// Format: "left|ws:pre|fg:#333|lh:1.5|fw:700".
  static String? _extractProp(String? raw, String prefix) {
    if (raw == null || !raw.contains('|')) {
      // Simple format: just check startsWith for backward compat
      if (raw != null && raw.startsWith('$prefix:')) {
        return raw.substring(prefix.length + 1);
      }
      return null;
    }
    for (final part in raw.split('|')) {
      if (part.startsWith('$prefix:')) return part.substring(prefix.length + 1);
    }
    return null;
  }

  /// Parse TextAlign from Rust bridge text_align (pipe-separated format).
  static TextAlign? _parseTextAlignFromRust(String? raw) {
    if (raw == null) return null;
    if (!raw.contains('|')) {
      // Simple format
      if (raw.startsWith('ws:')) return null;
      return TextAlign.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => TextAlign.left,
      );
    }
    // Pipe-separated: find the first part without a colon
    for (final part in raw.split('|')) {
      if (!part.contains(':')) {
        return TextAlign.values.firstWhere(
          (e) => e.name == part,
          orElse: () => TextAlign.left,
        );
      }
    }
    return null;
  }

  static local.BlockType _toBlockType(rust_models.BlockType rbt) {
    return switch (rbt) {
      rust_models.BlockType.heading => local.BlockType.heading,
      rust_models.BlockType.image => local.BlockType.image,
      rust_models.BlockType.quote => local.BlockType.quote,
      rust_models.BlockType.footnote => local.BlockType.footnote,
      rust_models.BlockType.separator => local.BlockType.separator,
      rust_models.BlockType.table => local.BlockType.table,
      rust_models.BlockType.list => local.BlockType.list,
      rust_models.BlockType.epigraph => local.BlockType.epigraph,
      rust_models.BlockType.poem => local.BlockType.poem,
      rust_models.BlockType.cite => local.BlockType.cite,
      rust_models.BlockType.textAuthor => local.BlockType.textAuthor,
      rust_models.BlockType.subtitle => local.BlockType.subtitle,
      rust_models.BlockType.listItem => local.BlockType.listItem,
      rust_models.BlockType.preformatted => local.BlockType.preformatted,
      rust_models.BlockType.paragraph => local.BlockType.paragraph,
    };
  }
}

import 'dart:io';
import 'dart:typed_data';

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
      final book = await rust_api.parseBook(
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
    final file = File(filePath);
    if (!await file.exists()) {
      throw ParserFailure('File not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ParserFailure('File is empty: $filePath');
    }
    final fileName = filePath.split(Platform.pathSeparator).last;
    return parse(bytes, fileName: fileName, forcedEncoding: forcedEncoding);
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
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      metadata: r.metadata != null ? Map<String, dynamic>.from(r.metadata! as Map) : null,
    );
  }

  static local.BlockType _toBlockType(rust_models.BlockType rbt) {
    if (rbt == rust_models.BlockType.heading) return local.BlockType.heading;
    if (rbt == rust_models.BlockType.image) return local.BlockType.image;
    if (rbt == rust_models.BlockType.quote) return local.BlockType.quote;
    if (rbt == rust_models.BlockType.footnote) return local.BlockType.footnote;
    if (rbt == rust_models.BlockType.separator) return local.BlockType.separator;
    return local.BlockType.paragraph;
  }
}

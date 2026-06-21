import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import 'book_open_service.dart';
import 'parsers/cbr_parser.dart';
import 'parsers/cbz_parser.dart';
import 'parsers/format_detector.dart';
import 'parsers/normalized_book.dart';
import 'parsers/parser_registry.dart';
import 'parsers/rust_book_parser.dart';

final bookParserRegistryProvider = Provider<BookParserRegistry>((ref) {
  return BookParserRegistry.defaultInstance;
});

final bookImporterProvider = Provider<BookImporter>((ref) {
  return BookImporter(
    registry: ref.watch(bookParserRegistryProvider),
    bookOpenService: ref.watch(bookOpenServiceProvider),
  );
});

class ImportedBookResult {
  const ImportedBookResult({
    required this.title,
    required this.format,
  });

  final String title;
  final String format;
}

final class BookImporter {
  BookImporter({
    required this.registry,
    required this.bookOpenService,
  });

  final BookParserRegistry registry;
  final BookOpenService bookOpenService;

  Future<NormalizedBook> parseInBackground(String filePath) async {
    final format = detectBookFormat(filePath);
    if (format == BookFormat.unknown) {
      throw const UnsupportedFormatFailure('Неподдерживаемый формат файла');
    }
    if (format == BookFormat.pdf || format == BookFormat.djvu) {
      throw const UnsupportedFormatFailure('Формат не поддерживается');
    }

    return Isolate.run<NormalizedBook>(() {
      return switch (format) {
        BookFormat.epub ||
        BookFormat.fb2 ||
        BookFormat.txt ||
        BookFormat.rtf ||
        BookFormat.mobi ||
        BookFormat.azw3 ||
        BookFormat.prc ||
        BookFormat.docx => RustBookParser().parseFile(filePath),
        BookFormat.cbz => CbzParser().parseFile(filePath),
        BookFormat.cbr => CbrParser().parseFile(filePath),
        BookFormat.pdf => throw UnsupportedError('PDF uses separate viewer'),
        BookFormat.djvu => throw UnsupportedError('DJVU not supported'),
        BookFormat.unknown => throw UnsupportedError('Unknown format'),
      };
    });
  }
}

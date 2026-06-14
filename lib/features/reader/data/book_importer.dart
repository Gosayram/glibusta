import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import 'book_open_service.dart';
import 'parsers/epub_parser.dart';
import 'parsers/fb2_parser.dart';
import 'parsers/format_detector.dart';
import 'parsers/normalized_book.dart';
import 'parsers/parser_registry.dart';
import 'parsers/rtf_parser.dart';
import 'parsers/txt_parser.dart';

final bookParserRegistryProvider = Provider<BookParserRegistry>((ref) {
  return BookParserRegistry([
    EpubParser(),
    Fb2Parser(),
    TxtBookParser(),
    RtfBookParser(),
  ]);
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
      throw const BookOpenFailure('Неподдерживаемый формат файла');
    }
    if (format == BookFormat.pdf || format == BookFormat.mobi || format == BookFormat.djvu) {
      throw const BookOpenFailure('Формат не поддерживается');
    }

    return Isolate.run<NormalizedBook>(() {
      return switch (format) {
        BookFormat.epub => EpubParser().parseFile(filePath),
        BookFormat.fb2 => Fb2Parser().parseFile(filePath),
        BookFormat.txt => TxtBookParser().parseFile(filePath),
        BookFormat.rtf => RtfBookParser().parseFile(filePath),
        BookFormat.pdf => throw UnsupportedError('PDF uses separate viewer'),
        BookFormat.mobi => throw UnsupportedError('MOBI not supported'),
        BookFormat.djvu => throw UnsupportedError('DJVU not supported'),
        BookFormat.unknown => throw UnsupportedError('Unknown format'),
      };
    });
  }
}

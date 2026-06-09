import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';

enum QuoteExportFormat { markdown, txt, json }

class QuoteExportService {
  QuoteExportService(this._db, this._logger);
  final AppDatabase _db;
  final AppLogger _logger;

  Future<List<Map<String, dynamic>>> getQuotesForBook(String bookId) async {
    final quotes =
        await (_db.select(_db.quotes)
              ..where((q) => q.bookId.equals(bookId))
              ..orderBy([(q) => OrderingTerm.asc(q.chapterIndex)]))
            .get();

    return quotes
        .map(
          (q) => {
            'id': q.id,
            'bookId': q.bookId,
            'chapterIndex': q.chapterIndex,
            'paragraphIndex': q.paragraphIndex,
            'text': q.selectedText,
            'beforeContext': q.beforeContext,
            'afterContext': q.afterContext,
            'note': q.note,
            'createdAt': q.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllQuotes() async {
    final quotes = await (_db.select(
      _db.quotes,
    )..orderBy([(q) => OrderingTerm.desc(q.createdAt)])).get();

    return quotes
        .map(
          (q) => {
            'id': q.id,
            'bookId': q.bookId,
            'chapterIndex': q.chapterIndex,
            'paragraphIndex': q.paragraphIndex,
            'text': q.selectedText,
            'beforeContext': q.beforeContext,
            'afterContext': q.afterContext,
            'note': q.note,
            'createdAt': q.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  String exportAsMarkdown(List<Map<String, dynamic>> quotes, {String? bookTitle}) {
    final sb = StringBuffer();
    if (bookTitle != null) {
      sb.writeln('# Цитаты из «$bookTitle»\n');
    } else {
      sb.writeln('# Мои цитаты\n');
    }
    sb.writeln('Экспорт: ${DateTime.now().toIso8601String()}\n');
    sb.writeln('---\n');

    for (final q in quotes) {
      sb.writeln('> ${q['text']}\n');
      if (q['note'] != null && (q['note'] as String).isNotEmpty) {
        sb.writeln('*${q['note']}*\n');
      }
      sb.writeln('— ${q['bookId']}, глава ${q['chapterIndex']}\n');
      sb.writeln('---\n');
    }

    return sb.toString();
  }

  String exportAsTxt(List<Map<String, dynamic>> quotes, {String? bookTitle}) {
    final sb = StringBuffer();
    if (bookTitle != null) {
      sb.writeln('ЦИТАТЫ ИЗ «$bookTitle»');
    } else {
      sb.writeln('МОИ ЦИТАТЫ');
    }
    sb.writeln('Экспорт: ${DateTime.now()}');
    sb.writeln('${'=' * 40}\n');

    for (final q in quotes) {
      sb.writeln('"${q['text']}"');
      if (q['note'] != null && (q['note'] as String).isNotEmpty) {
        sb.writeln('  Заметка: ${q['note']}');
      }
      sb.writeln('  [${q['bookId']}, глава ${q['chapterIndex']}]');
      sb.writeln();
    }

    return sb.toString();
  }

  String exportAsJson(List<Map<String, dynamic>> quotes) {
    final export = {
      'exportedAt': DateTime.now().toIso8601String(),
      'count': quotes.length,
      'quotes': quotes,
    };

    // Manual JSON to avoid dart:convert import
    final sb = StringBuffer('{\n');
    sb.write('  "exportedAt": "${export['exportedAt']}",\n');
    sb.write('  "count": ${export['count']},\n');
    sb.write('  "quotes": [\n');
    for (var i = 0; i < quotes.length; i++) {
      final q = quotes[i];
      sb.write('    {\n');
      sb.write('      "id": "${q['id']}",\n');
      sb.write('      "bookId": "${q['bookId']}",\n');
      sb.write('      "text": "${_escapeJson(q['text'] as String)}",\n');
      if (q['note'] != null) {
        sb.write('      "note": "${_escapeJson(q['note'] as String)}",\n');
      }
      sb.write('      "chapterIndex": ${q['chapterIndex']},\n');
      sb.write('      "createdAt": "${q['createdAt']}"\n');
      sb.write('    }${i < quotes.length - 1 ? ',' : ''}\n');
    }
    sb.write('  ]\n}');
    return sb.toString();
  }

  String _escapeJson(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');
  }

  Future<String> exportToFile({
    required QuoteExportFormat format,
    String? bookId,
    String? bookTitle,
  }) async {
    final quotes = bookId != null ? await getQuotesForBook(bookId) : await getAllQuotes();

    String content;
    String extension;

    switch (format) {
      case QuoteExportFormat.markdown:
        content = exportAsMarkdown(quotes, bookTitle: bookTitle);
        extension = 'md';
      case QuoteExportFormat.txt:
        content = exportAsTxt(quotes, bookTitle: bookTitle);
        extension = 'txt';
      case QuoteExportFormat.json:
        content = exportAsJson(quotes);
        extension = 'json';
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = bookId != null
        ? 'quotes_${bookId}_${DateTime.now().millisecondsSinceEpoch}.$extension'
        : 'quotes_all_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File('${dir.path}/exports/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    _logger.info('Quotes exported: ${file.path} (${quotes.length} quotes)', name: 'QuoteExport');
    return file.path;
  }
}

// --- Riverpod providers ---

final quoteExportServiceProvider = Provider<QuoteExportService>((ref) {
  throw UnimplementedError('Override in main');
});

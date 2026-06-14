import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../data/parsers/format_detector.dart';
import 'djvu_reader_screen.dart';
import 'pdf_reader_screen.dart';
import 'reader_screen.dart';

final readerFileProvider = FutureProvider.family<_ReaderFileState?, String>((ref, bookId) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.downloads)..where((d) => d.bookId.equals(bookId))).get();
  for (final row in rows) {
    if (row.status == DownloadStatusDb.completed) {
      final path = row.targetPath;
      return _ReaderFileState(
        download: row,
        exists: path != null && path.isNotEmpty && await File(path).exists(),
      );
    }
  }
  return null;
});

class _ReaderFileState {
  const _ReaderFileState({required this.download, required this.exists});

  final Download download;
  final bool exists;
}

class ReaderEntryScreen extends ConsumerWidget {
  const ReaderEntryScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadAsync = ref.watch(readerFileProvider(bookId));
    return downloadAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _ReaderOpenError(message: error.toString()),
      data: (fileState) {
        final path = fileState?.download.targetPath;
        if (path == null || path.isEmpty) {
          return const _ReaderOpenError(message: 'Путь к файлу не указан');
        }
        if (fileState == null || !fileState.exists) {
          return _ReaderOpenError(message: 'Файл не найден: $path');
        }

        return switch (detectBookFormat(path)) {
          BookFormat.pdf => PdfReaderScreen(filePath: path),
          BookFormat.djvu => DjvuReaderScreen(filePath: path),
          BookFormat.epub ||
          BookFormat.fb2 ||
          BookFormat.txt ||
          BookFormat.rtf ||
          BookFormat.mobi ||
          BookFormat.azw3 ||
          BookFormat.prc => ReaderScreen(bookId: bookId),
          BookFormat.unknown => _ReaderOpenError(message: 'Формат не поддерживается: $path'),
        };
      },
    );
  }
}

class _ReaderOpenError extends StatelessWidget {
  const _ReaderOpenError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Открытие книги')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

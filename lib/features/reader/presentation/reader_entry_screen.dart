import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formats/format_capability.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../library/domain/book_file_repository.dart';
import '../data/online_read_service.dart';
import '../data/parsers/format_detector.dart';
import '../domain/reader.dart';
import 'djvu_reader_screen.dart';
import 'pdf_reader_screen.dart';
import 'reader_screen.dart';

/// Resolves the local file path for a book: an online-read temp copy (via the
/// registry) takes precedence, then the downloads table, then saved books.
final readerFilePathProvider = FutureProvider.family<({String path, bool exists}), String>(
  (ref, bookId) async {
    final path = await ref.watch(bookFileRepositoryProvider).getFilePath(bookId);
    final exists = path != null && path.isNotEmpty && await File(path).exists();
    return (path: path ?? '', exists: exists);
  },
);

class ReaderEntryScreen extends ConsumerStatefulWidget {
  const ReaderEntryScreen({super.key, required this.bookId, this.initialPosition});

  final String bookId;
  final ReaderPosition? initialPosition;

  @override
  ConsumerState<ReaderEntryScreen> createState() => _ReaderEntryScreenState();
}

class _ReaderEntryScreenState extends ConsumerState<ReaderEntryScreen> {
  @override
  void dispose() {
    // Clean up an online-read temp file, if this session used one. A no-op for
    // books opened from the library downloads.
    unawaited(
      ref.read(onlineReadServiceProvider).dispose(widget.bookId).catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileAsync = ref.watch(readerFilePathProvider(widget.bookId));
    return fileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _ReaderOpenError(message: error.toString()),
      data: (data) {
        if (data.path.isEmpty) {
          return const _ReaderOpenError(message: 'Путь к файлу не указан');
        }
        if (!data.exists) {
          return const _ReaderOpenError(message: 'Файл книги не найден');
        }

        final format = detectBookFormat(data.path);
        if (format == BookFormat.pdf) {
          return PdfReaderScreen(filePath: data.path);
        }
        if (format == BookFormat.djvu) {
          return DjvuReaderScreen(filePath: data.path);
        }
        if (format.canReadInApp) {
          return ReaderScreen(bookId: widget.bookId, initialPosition: widget.initialPosition);
        }
        return const _ReaderOpenError(message: 'Формат не поддерживается');
      },
    );
  }
}

class _ReaderOpenError extends StatelessWidget {
  const _ReaderOpenError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    AppLogger().warning('Reader open error: $message', name: 'Reader');
    return Scaffold(
      appBar: const AdaptiveAppBar(title: Text('Открытие книги')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

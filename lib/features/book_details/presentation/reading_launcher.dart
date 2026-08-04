import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../reader/data/online_read_service.dart';

/// Opens a book for reading. Downloaded books open immediately; books not in
/// the library are fetched into a temp cache ("read online") and then opened
/// in the native reader. The temp file is cleaned up when the reader closes.
Future<void> startReading(
  BuildContext context,
  WidgetRef ref,
  Book book, {
  required bool isDownloaded,
  List<BookFormat>? availableFormats,
}) async {
  if (isDownloaded) {
    unawaited(context.push('/reader/${book.id}'));
    return;
  }

  final formats = availableFormats ?? book.availableFormats;
  if (formats.isEmpty) {
    unawaited(_toast(context, 'Нет доступных форматов для чтения'));
    return;
  }

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReadLoadingDialog(),
    ),
  );

  try {
    await ref.read(onlineReadServiceProvider).prepare(book.id, formats);
    if (!context.mounted) return;
    unawaited(context.push('/reader/${book.id}'));
  } on OnlineReadFailure catch (e) {
    AppLogger().warning('Online read failed: ${e.message}', name: 'ReadingLauncher');
    if (context.mounted) unawaited(_toast(context, e.message));
  } on Object catch (e, st) {
    AppLogger().severe(
      'Online read failed for ${book.id}',
      name: 'ReadingLauncher',
      error: e,
      st: st,
    );
    if (context.mounted) unawaited(_toast(context, 'Не удалось открыть книгу'));
  } finally {
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<void> _toast(BuildContext context, String message) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(SnackBar(content: Text(message)));
}

class _ReadLoadingDialog extends StatelessWidget {
  const _ReadLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Text('Загрузка для чтения…', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

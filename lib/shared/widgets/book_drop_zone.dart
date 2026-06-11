import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/file_picker_service.dart';

class BookDropZone extends ConsumerWidget {
  final Widget child;
  final void Function(List<String> paths) onBooksDropped;

  const BookDropZone({
    super.key,
    required this.child,
    required this.onBooksDropped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _showImportDialog(context),
      child: Semantics(
        label: 'Зона для импорта книг',
        child: child,
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final picker = BookFilePicker();
    final paths = await picker.pickBookFiles();
    if (paths.isNotEmpty) {
      onBooksDropped(paths);
    }
  }
}

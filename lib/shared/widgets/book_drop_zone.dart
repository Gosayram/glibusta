import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['fb2', 'epub', 'txt'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (paths.isNotEmpty) {
      onBooksDropped(paths);
    }
  }
}

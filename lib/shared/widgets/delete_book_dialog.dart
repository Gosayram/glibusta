import 'package:flutter/material.dart';

class DeleteBookResult {
  final bool deleteFile;

  const DeleteBookResult({this.deleteFile = false});
}

class DeleteBookDialog extends StatefulWidget {
  final String bookTitle;

  const DeleteBookDialog({super.key, required this.bookTitle});

  @override
  State<DeleteBookDialog> createState() => _DeleteBookDialogState();

  static Future<DeleteBookResult?> show(BuildContext context, {required String bookTitle}) {
    return showDialog<DeleteBookResult>(
      context: context,
      builder: (context) => DeleteBookDialog(bookTitle: bookTitle),
    );
  }
}

class _DeleteBookDialogState extends State<DeleteBookDialog> {
  bool _deleteFile = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Удалить книгу?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '«${widget.bookTitle}»',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'Книга будет удалена из списка библиотеки.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _deleteFile,
            onChanged: (value) => setState(() => _deleteFile = value ?? false),
            title: const Text('Удалить файл с диска'),
            subtitle: const Text('Файл книги будет удалён навсегда'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(
            DeleteBookResult(deleteFile: _deleteFile),
          ),
          child: const Text('Удалить'),
        ),
      ],
    );
  }
}

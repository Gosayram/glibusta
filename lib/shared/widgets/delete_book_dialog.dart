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
          const SizedBox(height: 12),
          Text(
            'Выберите действие:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const DeleteBookResult(),
          ),
          child: const Text('Из списка'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(
            const DeleteBookResult(deleteFile: true),
          ),
          child: const Text('С файлом'),
        ),
      ],
    );
  }
}

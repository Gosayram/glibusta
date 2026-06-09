import 'package:flutter/material.dart';

enum DeleteBookMode {
  fileOnly,
  fileWithNotes,
  completely,
}

class DeleteBookDialog extends StatelessWidget {
  final String bookTitle;

  const DeleteBookDialog({super.key, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить книгу?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('«$bookTitle»'),
          const SizedBox(height: 16),
          const Text('Что именно удалить?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(DeleteBookMode.fileOnly),
          child: const Text('Только файл'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(DeleteBookMode.fileWithNotes),
          child: const Text('Файл + заметки'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(DeleteBookMode.completely),
          child: const Text('Полностью'),
        ),
      ],
    );
  }

  static Future<DeleteBookMode?> show(BuildContext context, {required String bookTitle}) {
    return showDialog<DeleteBookMode>(
      context: context,
      builder: (context) => DeleteBookDialog(bookTitle: bookTitle),
    );
  }
}
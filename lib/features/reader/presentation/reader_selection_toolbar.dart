import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../core/database/app_database.dart';

class ReaderSelectionToolbar extends ConsumerStatefulWidget {
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final VoidCallback onDismiss;

  const ReaderSelectionToolbar({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.onDismiss,
  });

  @override
  ConsumerState<ReaderSelectionToolbar> createState() => _ReaderSelectionToolbarState();
}

class _ReaderSelectionToolbarState extends ConsumerState<ReaderSelectionToolbar> {
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    unawaited(_getSelectedText());
  }

  Future<void> _getSelectedText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted && data?.text != null && data!.text!.isNotEmpty) {
      setState(() => _selectedText = data.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarButton(
              icon: Icons.copy,
              label: 'Копировать',
              onTap: () async {
                if (_selectedText != null) {
                  await Clipboard.setData(ClipboardData(text: _selectedText!));
                  if (context.mounted) {
                    unawaited(SmartDialog.showToast('Текст скопирован'));
                  }
                }
                widget.onDismiss();
              },
            ),
            _ToolbarButton(
              icon: Icons.bookmark_add,
              label: 'Закладка',
              onTap: () => unawaited(_addBookmark(context)),
            ),
            _ToolbarButton(
              icon: Icons.sticky_note_2,
              label: 'Заметка',
              onTap: () => unawaited(_addNote(context)),
            ),
            _ToolbarButton(
              icon: Icons.format_quote,
              label: 'Цитата',
              onTap: () => unawaited(_addQuote(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBookmark(BuildContext context) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: '${widget.bookId}-${DateTime.now().millisecondsSinceEpoch}',
            bookId: widget.bookId,
            chapterIndex: widget.chapterIndex,
            paragraphIndex: widget.paragraphIndex,
            selectedText: Value(_selectedText),
          ),
        );
    if (context.mounted) {
      unawaited(SmartDialog.showToast('Закладка добавлена'));
    }
    widget.onDismiss();
  }

  Future<void> _addNote(BuildContext context) async {
    final textController = TextEditingController(text: _selectedText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedText != null && _selectedText!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedText!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Введите заметку...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final db = ref.read(databaseProvider);
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: '${widget.bookId}-${DateTime.now().millisecondsSinceEpoch}',
              bookId: widget.bookId,
              chapterIndex: widget.chapterIndex,
              paragraphIndex: widget.paragraphIndex,
              content: result,
            ),
          );
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Заметка сохранена'));
      }
    }
    widget.onDismiss();
  }

  Future<void> _addQuote(BuildContext context) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Цитата'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                _selectedText!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Комментарий (необязательно)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final db = ref.read(databaseProvider);
      await db
          .into(db.quotes)
          .insert(
            QuotesCompanion.insert(
              id: '${widget.bookId}-${DateTime.now().millisecondsSinceEpoch}',
              bookId: widget.bookId,
              chapterIndex: widget.chapterIndex,
              paragraphIndex: widget.paragraphIndex,
              selectedText: _selectedText!,
              note: result.isNotEmpty ? Value(result) : const Value.absent(),
            ),
          );
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Цитата сохранена'));
      }
    }
    widget.onDismiss();
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

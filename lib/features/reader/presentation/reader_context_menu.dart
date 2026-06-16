import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';

class ReaderContextMenu extends StatelessWidget {
  final SelectableRegionState state;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;

  const ReaderContextMenu({
    super.key,
    required this.state,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
  });

  @override
  Widget build(BuildContext context) {
    final selectedText = _getSelectedText();
    if (selectedText.isEmpty) return const SizedBox.shrink();

    final buttonItems = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(Clipboard.setData(ClipboardData(text: selectedText)));
        },
        label: 'Копировать',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(_saveQuote(context, selectedText));
        },
        label: 'Цитата',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(_saveBookmark(context, selectedText));
        },
        label: 'Закладка',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(_saveNote(context, selectedText));
        },
        label: 'Заметка',
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  String _getSelectedText() {
    // ignore: deprecated_member_use
    final selection = state.textEditingValue.selection;
    if (!selection.isCollapsed) {
      // ignore: deprecated_member_use
      return selection.textInside(state.textEditingValue.text);
    }
    return '';
  }

  Future<void> _saveQuote(BuildContext context, String text) async {
    if (!context.mounted) return;
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
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
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
      try {
        final db = ProviderScope.containerOf(context).read(databaseProvider);
        await db
            .into(db.quotes)
            .insert(
              QuotesCompanion.insert(
                id: '$bookId-${DateTime.now().millisecondsSinceEpoch}',
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                selectedText: text,
                note: Value(result.isEmpty ? null : result),
              ),
            );
        AppLogger().fine('quote saved for chapter $chapterIndex', name: 'Reader');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Цитата сохранена')),
          );
        }
      } on Object catch (e) {
        AppLogger().warning('Failed to save quote: $e', name: 'Reader', error: e);
      }
    }
  }

  Future<void> _saveBookmark(BuildContext context, String text) async {
    if (!context.mounted) return;
    try {
      final db = ProviderScope.containerOf(context).read(databaseProvider);
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: '$bookId-${DateTime.now().millisecondsSinceEpoch}',
              bookId: bookId,
              chapterIndex: chapterIndex,
              paragraphIndex: paragraphIndex,
              selectedText: Value(text),
            ),
          );
      AppLogger().fine('bookmark saved for chapter $chapterIndex', name: 'Reader');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Закладка сохранена')),
        );
      }
    } on Object catch (e) {
      AppLogger().warning('Failed to save bookmark: $e', name: 'Reader', error: e);
    }
  }

  Future<void> _saveNote(BuildContext context, String text) async {
    if (!context.mounted) return;
    final textController = TextEditingController(text: text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
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
      try {
        final db = ProviderScope.containerOf(context).read(databaseProvider);
        await db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: '$bookId-${DateTime.now().millisecondsSinceEpoch}',
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                content: result,
              ),
            );
        AppLogger().fine('note saved for chapter $chapterIndex', name: 'Reader');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заметка сохранена')),
          );
        }
      } on Object catch (e) {
        AppLogger().warning('Failed to save note: $e', name: 'Reader', error: e);
      }
    }
  }
}

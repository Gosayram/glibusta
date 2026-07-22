import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/tts_controller.dart';
import '../../../core/utils/monotonic_id.dart';

class ReaderSelectionToolbar extends ConsumerStatefulWidget {
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final String selectedText;
  final VoidCallback onDismiss;
  final ValueChanged<String>? onSearchInBook;

  const ReaderSelectionToolbar({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.selectedText,
    required this.onDismiss,
    this.onSearchInBook,
  });

  @override
  ConsumerState<ReaderSelectionToolbar> createState() => _ReaderSelectionToolbarState();
}

class _ReaderSelectionToolbarState extends ConsumerState<ReaderSelectionToolbar> {
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _selectedText = widget.selectedText;
  }

  @override
  void didUpdateWidget(covariant ReaderSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedText != oldWidget.selectedText) {
      _selectedText = widget.selectedText;
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
              icon: Icons.share,
              label: 'Поделиться',
              onTap: () async {
                if (_selectedText != null && _selectedText!.isNotEmpty) {
                  await SharePlus.instance.share(
                    ShareParams(text: _selectedText),
                  );
                }
                widget.onDismiss();
              },
            ),
            _ToolbarButton(
              icon: Icons.search,
              label: 'В поиске',
              onTap: () async {
                if (_selectedText != null && _selectedText!.isNotEmpty) {
                  final query = Uri.encodeComponent(_selectedText!);
                  final uri = Uri.parse('https://www.google.com/search?q=$query');
                  try {
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched && context.mounted) {
                      unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                    }
                  } on Object {
                    if (context.mounted) {
                      unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                    }
                  }
                }
                widget.onDismiss();
              },
            ),
            // HG-7.5: in-book search from context
            if (widget.onSearchInBook != null && _selectedText != null)
              _ToolbarButton(
                icon: Icons.menu_book,
                label: 'В книге',
                onTap: () {
                  widget.onSearchInBook!(_selectedText!);
                  widget.onDismiss();
                },
              ),
            _ToolbarButton(
              icon: Icons.translate,
              label: 'Перевод',
              onTap: () async {
                if (_selectedText != null && _selectedText!.isNotEmpty) {
                  final query = Uri.encodeComponent(_selectedText!);
                  final uri = Uri.parse('https://translate.google.com/?sl=auto&tl=ru&text=$query');
                  try {
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched && context.mounted) {
                      unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                    }
                  } on Object {
                    if (context.mounted) {
                      unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                    }
                  }
                }
                widget.onDismiss();
              },
            ),
            // MD-3.2: inline dictionary popup via Wiktionary REST API
            _ToolbarButton(
              icon: Icons.menu_book,
              label: 'Словарь',
              onTap: () async {
                if (_selectedText != null && _selectedText!.isNotEmpty) {
                  final query = _selectedText!.trim();
                  if (context.mounted) {
                    unawaited(_showDictPopup(context, query));
                  }
                }
                widget.onDismiss();
              },
            ),
            // HG-7.7: Wikipedia search
            _ToolbarButton(
              icon: Icons.language,
              label: 'Википедия',
              onTap: () async {
                if (_selectedText != null && _selectedText!.isNotEmpty) {
                  final query = Uri.encodeComponent(_selectedText!);
                  final uri = Uri.parse('https://ru.wikipedia.org/wiki/$query');
                  try {
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched && context.mounted) {
                      unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                    }
                  } on Object {
                    if (context.mounted) {
                      unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                    }
                  }
                }
                widget.onDismiss();
              },
            ),
            // HG-7.6: TTS from context; LW-11.2: resume last if available
            if (_selectedText != null && _selectedText!.isNotEmpty)
              _ToolbarButton(
                icon: Icons.volume_up,
                label: TtsController.instance.hasLastText ? 'Возобновить' : 'Озвучить',
                onTap: () {
                  if (TtsController.instance.hasLastText) {
                    unawaited(TtsController.instance.resume());
                  } else {
                    unawaited(_speakText(_selectedText!));
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
            _ToolbarButton(
              icon: Icons.highlight,
              label: 'Выделить',
              onTap: () => unawaited(_addHighlight(context)),
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
            id: '${widget.bookId}-${newMonotonicId()}',
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
              id: '${widget.bookId}-${newMonotonicId()}',
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
              id: '${widget.bookId}-${newMonotonicId()}',
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

  // MD-21.2: highlight immediately with yellow, no menu
  // ponytail: color picker removed; add if per-color quick-highlight setting is needed
  Future<void> _addHighlight(BuildContext context) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db
        .into(db.textHighlights)
        .insert(
          TextHighlightsCompanion.insert(
            id: '${widget.bookId}-${newMonotonicId()}',
            bookId: widget.bookId,
            chapterId: widget.chapterIndex.toString(),
            chapterIndex: widget.chapterIndex,
            blockIndex: widget.paragraphIndex,
            startOffset: 0,
            endOffset: _selectedText!.length,
            selectedText: _selectedText!,
            color: const Value('yellow'),
          ),
        );
    if (context.mounted) {
      unawaited(SmartDialog.showToast('Текст выделен'));
    }
    widget.onDismiss();
  }

  // ponytail: single Wiktionary API, no offline cache, no multi-lang picker
  Future<void> _showDictPopup(BuildContext context, String query) async {
    try {
      final client = HttpClient();
      final uri = Uri.https(
        'en.wiktionary.org',
        '/api/rest_v1/page/summary/${Uri.encodeComponent(query)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      if (!context.mounted) {
        client.close();
        return;
      }

      if (response.statusCode != 200) {
        client.close();
        unawaited(SmartDialog.showToast('Ничего не найдено'));
        return;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final title = data['title'] as String? ?? query;
      final extract = data['extract'] as String? ?? '';

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(extract.isNotEmpty ? extract : 'Нет определения'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Ошибка словаря: $e'));
      }
    }
  }

  Future<void> _speakText(String text) async {
    try {
      await TtsController.instance.speak(text, lang: 'ru-RU', rate: 0.5);
    } on Object catch (e) {
      debugPrint('TTS error: $e');
    }
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

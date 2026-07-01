import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import 'highlight_providers.dart';

class HighlightsNotesScreen extends ConsumerWidget {
  final String bookId;

  const HighlightsNotesScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(bookHighlightsProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выделения и заметки'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final highlights = highlightsAsync.value;
              if (highlights == null || highlights.isEmpty) return;
              if (value == 'anki') {
                await _exportAnki(context, ref, highlights);
              } else if (value == 'markdown') {
                await _exportMarkdown(context, ref, highlights);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'anki', child: Text('Экспорт в Anki (TSV)')),
              PopupMenuItem(value: 'markdown', child: Text('Экспорт в Markdown')),
            ],
          ),
        ],
      ),
      body: highlightsAsync.when(
        data: (highlights) {
          if (highlights.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.highlight_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет выделений',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Выделяйте текст при чтении',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => context.go('/library'),
                    child: const Text('Открыть библиотеку'),
                  ),
                ],
              ),
            );
          }

          final colorGroups = <String, List<TextHighlight>>{};
          for (final h in highlights) {
            colorGroups.putIfAbsent(h.color, () => []).add(h);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${highlights.length} ${_countLabel(highlights.length)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              for (final entry in colorGroups.entries)
                _buildColorSection(context, ref, entry.key, entry.value),
            ],
          );
        },
        loading: () => Skeletonizer(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => const Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(title: Text('Текст выделения...')),
            ),
          ),
        ),
        error: (error, stack) => Center(
          child: Text('Ошибка: $error'),
        ),
      ),
    );
  }

  // MD-4.3: Anki TSV export — front=selected text, back=note or chapter context
  Future<void> _exportAnki(
    BuildContext context,
    WidgetRef ref,
    List<TextHighlight> highlights,
  ) async {
    final db = ref.read(databaseProvider);
    final book = await db.bookDao.getBookById(bookId);
    final bookTitle = book?.title ?? 'Книга';
    final buffer = StringBuffer();
    buffer.writeln('#Sep=Tab');
    buffer.writeln('Text\tExtra\tTags');
    for (final h in highlights) {
      final front = h.selectedText.replaceAll('\t', ' ').replaceAll('\n', ' ');
      final note = (h.noteText ?? '').replaceAll('\t', ' ').replaceAll('\n', ' ');
      final back = note.isNotEmpty ? note : 'Глава ${h.chapterIndex + 1}';
      buffer.writeln('$front\t$back\t$bookTitle');
    }
    await _shareFile(buffer.toString(), 'anki_cards.txt', 'Anki cards');
  }

  // MD-4.4: Markdown export with hashtags for Notion/Obsidian
  Future<void> _exportMarkdown(
    BuildContext context,
    WidgetRef ref,
    List<TextHighlight> highlights,
  ) async {
    final db = ref.read(databaseProvider);
    final book = await db.bookDao.getBookById(bookId);
    final bookTitle = book?.title ?? 'Книга';
    final allAuthors = await db.authorDao.getAllAuthors();
    final authorMap = {for (final a in allAuthors) a.id: a.name};
    final authors = book?.authorIds.map((id) => authorMap[id]).whereType<String>().join(', ') ?? '';
    final buffer = StringBuffer();
    buffer.writeln('# Выделения — $bookTitle');
    if (authors.isNotEmpty) buffer.writeln('_Автор: ${authors}_');
    buffer.writeln();
    for (final h in highlights) {
      buffer.writeln('> ${h.selectedText}');
      if (h.noteText != null && h.noteText!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('**Заметка:** ${h.noteText}');
      }
      buffer.writeln();
      buffer.writeln('#${bookTitle.replaceAll(' ', '_')} #глава${h.chapterIndex + 1}');
      buffer.writeln('---');
      buffer.writeln();
    }
    await _shareFile(buffer.toString(), 'highlights.md', 'Markdown');
  }

  Future<void> _shareFile(String content, String filename, String label) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/glibusta/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: label),
      );
    } on Object {
      unawaited(SmartDialog.showToast('Не удалось экспортировать'));
    }
  }

  String _countLabel(int count) {
    if (count == 1) return 'выделение';
    if (count >= 2 && count <= 4) return 'выделения';
    return 'выделений';
  }

  Widget _buildColorSection(
    BuildContext context,
    WidgetRef ref,
    String color,
    List<TextHighlight> highlights,
  ) {
    final colorValue = _getColorValue(color);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorValue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_colorName(color)} (${highlights.length})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          ...highlights.map(
            (h) => _HighlightTile(
              highlight: h,
              colorValue: colorValue,
              onDeleted: () => _deleteHighlight(context, ref, h),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHighlight(
    BuildContext context,
    WidgetRef ref,
    TextHighlight highlight,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выделение?'),
        content: Text(
          '"${highlight.selectedText.substring(0, highlight.selectedText.length.clamp(0, 50))}${highlight.selectedText.length > 50 ? '...' : ''}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(highlightRepositoryProvider).deleteHighlight(highlight.id);
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Выделение удалено'));
      }
    }
  }

  Color _getColorValue(String color) {
    return switch (color) {
      'green' => const Color(0xFF4CAF50),
      'blue' => const Color(0xFF2196F3),
      'red' => const Color(0xFFF44336),
      'purple' => const Color(0xFF9C27B0),
      'orange' => const Color(0xFFFF9800),
      _ => const Color(0xFFFFEB3B),
    };
  }

  String _colorName(String color) {
    return switch (color) {
      'green' => 'Зелёный',
      'blue' => 'Синий',
      'red' => 'Красный',
      'purple' => 'Фиолетовый',
      'orange' => 'Оранжевый',
      _ => 'Жёлтый',
    };
  }
}

class _HighlightTile extends StatelessWidget {
  final TextHighlight highlight;
  final Color colorValue;
  final VoidCallback onDeleted;

  const _HighlightTile({
    required this.highlight,
    required this.colorValue,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: colorValue),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      highlight.selectedText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (highlight.noteText != null && highlight.noteText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        highlight.noteText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Гл. ${highlight.chapterIndex + 1} · Абз. ${highlight.blockIndex + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDeleted,
              tooltip: 'Удалить',
            ),
          ],
        ),
      ),
    );
  }
}

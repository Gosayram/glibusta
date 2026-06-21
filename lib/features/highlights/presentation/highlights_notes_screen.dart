import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../highlights/presentation/highlight_providers.dart';

class HighlightsNotesScreen extends ConsumerWidget {
  final String bookId;

  const HighlightsNotesScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(bookHighlightsProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выделения и заметки'),
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

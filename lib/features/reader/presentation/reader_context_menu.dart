import 'package:flutter/material.dart';

enum ContextMenuAction {
  copy,
  highlight,
  underline,
  translate,
  narrate,
  share,
  search,
  ai,
}

class ReaderContextMenu extends StatelessWidget {
  const ReaderContextMenu({
    this.selectedText = '',
    this.onAction,
    this.state,
    this.bookId,
    this.chapterIndex,
    this.paragraphIndex,
    super.key,
  });

  final String selectedText;
  final void Function(ContextMenuAction action)? onAction;
  final dynamic state;
  final String? bookId;
  final int? chapterIndex;
  final int? paragraphIndex;

  static Future<void> show({
    required BuildContext context,
    required String selectedText,
    required void Function(ContextMenuAction action) onAction,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (_) => ReaderContextMenu(
        selectedText: selectedText,
        onAction: (action) {
          Navigator.of(context).pop();
          onAction(action);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedText.length > 200 ? '${selectedText.substring(0, 200)}...' : selectedText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              actions: const [
                _ActionItem(icon: Icons.copy, label: 'Копировать', action: ContextMenuAction.copy),
                _ActionItem(
                  icon: Icons.highlight,
                  label: 'Подсветка',
                  action: ContextMenuAction.highlight,
                ),
                _ActionItem(
                  icon: Icons.format_underlined,
                  label: 'Подчёркивание',
                  action: ContextMenuAction.underline,
                ),
                _ActionItem(
                  icon: Icons.translate,
                  label: 'Перевод',
                  action: ContextMenuAction.translate,
                ),
                _ActionItem(
                  icon: Icons.volume_up,
                  label: 'Озвучить',
                  action: ContextMenuAction.narrate,
                ),
                _ActionItem(
                  icon: Icons.share,
                  label: 'Поделиться',
                  action: ContextMenuAction.share,
                ),
                _ActionItem(icon: Icons.search, label: 'Поиск', action: ContextMenuAction.search),
                _ActionItem(icon: Icons.smart_toy, label: 'AI', action: ContextMenuAction.ai),
              ],
              onAction: onAction ?? (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.action,
  });

  final IconData icon;
  final String label;
  final ContextMenuAction action;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.actions,
    required this.onAction,
  });

  final List<_ActionItem> actions;
  final void Function(ContextMenuAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: actions.map((item) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onAction(item.action),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class HighlightColorPicker extends StatelessWidget {
  const HighlightColorPicker({required this.onColorSelected, super.key});

  final void Function(Color color) onColorSelected;

  static const _colors = [
    Color(0x40FFEB3B),
    Color(0x40FF9800),
    Color(0x404CAF50),
    Color(0x402196F3),
    Color(0x40E91E63),
  ];

  static const _colorNames = ['Жёлтый', 'Оранжевый', 'Зелёный', 'Синий', 'Розовый'];

  static Future<void> show({
    required BuildContext context,
    required void Function(Color color) onColorSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (_) => HighlightColorPicker(onColorSelected: onColorSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Цвет подсветки', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_colors.length, (i) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onColorSelected(_colors[i]);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _colorNames[i],
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

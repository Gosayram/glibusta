import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class CommandPaletteAction {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onExecute;

  const CommandPaletteAction({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onExecute,
  });
}

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  static void show(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => const CommandPalette(),
    ));
  }

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommandPaletteAction> _getActions() {
    final actions = <CommandPaletteAction>[
      // Navigation
      CommandPaletteAction(
        label: 'Библиотека',
        subtitle: 'Перейти к библиотеке',
        icon: Icons.library_books,
        onExecute: () => context.go('/library'),
      ),
      CommandPaletteAction(
        label: 'Поиск',
        subtitle: 'Перейти к поиску',
        icon: Icons.search,
        onExecute: () => context.go('/search'),
      ),
      CommandPaletteAction(
        label: 'Загрузки',
        subtitle: 'Перейти к загрузкам',
        icon: Icons.download,
        onExecute: () => context.go('/downloads'),
      ),
      CommandPaletteAction(
        label: 'Коллекции',
        subtitle: 'Перейти к коллекциям',
        icon: Icons.collections_bookmark,
        onExecute: () => context.go('/collections'),
      ),
      CommandPaletteAction(
        label: 'Настройки',
        subtitle: 'Перейти к настройкам',
        icon: Icons.settings,
        onExecute: () => context.go('/settings'),
      ),
      // Theme
      CommandPaletteAction(
        label: 'Тема: Светлая',
        subtitle: 'Переключить на светлую тему',
        icon: Icons.light_mode,
        onExecute: () {
          ref.read<ThemeModeNotifier>(themeModeProvider.notifier).setMode(ThemeMode.light);
        },
      ),
      CommandPaletteAction(
        label: 'Тема: Тёмная',
        subtitle: 'Переключить на тёмную тему',
        icon: Icons.dark_mode,
        onExecute: () {
          ref.read<ThemeModeNotifier>(themeModeProvider.notifier).setMode(ThemeMode.dark);
        },
      ),
      CommandPaletteAction(
        label: 'Тема: Системная',
        subtitle: 'Использовать системную тему',
        icon: Icons.brightness_auto,
        onExecute: () {
          ref.read<ThemeModeNotifier>(themeModeProvider.notifier).setMode(ThemeMode.system);
        },
      ),
    ];

    if (_query.isEmpty) return actions;

    return actions.where((a) {
      final q = _query.toLowerCase();
      return a.label.toLowerCase().contains(q) ||
          (a.subtitle?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _getActions();
    final theme = Theme.of(context);

    // Clamp selected index
    if (_selectedIndex >= actions.length) {
      _selectedIndex = actions.isEmpty ? 0 : actions.length - 1;
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent(),
      },
      child: Actions(
        actions: {
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 520,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Найти книгу, действие...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                        _selectedIndex = 0;
                      });
                    },
                    onSubmitted: (_) {
                      if (actions.isNotEmpty) {
                        actions[_selectedIndex].onExecute();
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                // Actions list
                Flexible(
                  child: actions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Ничего не найдено',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: actions.length,
                          itemBuilder: (context, index) {
                            final action = actions[index];
                            final isSelected = index == _selectedIndex;
                            return MouseRegion(
                              onEnter: (_) {
                                setState(() => _selectedIndex = index);
                              },
                              child: ListTile(
                                leading: Icon(
                                  action.icon,
                                  size: 20,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  action.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? theme.colorScheme.primary : null,
                                  ),
                                ),
                                subtitle: action.subtitle != null ? Text(action.subtitle!) : null,
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                onTap: () {
                                  action.onExecute();
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

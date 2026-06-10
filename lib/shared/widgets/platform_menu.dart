import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'command_palette.dart';

class PlatformMenuWidget extends ConsumerWidget implements PreferredSizeWidget {
  const PlatformMenuWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Glibusta',
          menus: [
            PlatformMenuItem(
              label: 'О программе',
              onSelected: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Glibusta',
                  applicationVersion: '0.1.0+1',
                  applicationIcon: const Icon(Icons.menu_book, size: 48),
                  children: const [
                    Text('Кросс-платформенная библиотека книг с Flibusta.'),
                  ],
                );
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'Файл',
          menus: [
            PlatformMenuItem(
              label: 'Открыть книгу...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
              onSelected: () {},
            ),
          ],
        ),
        PlatformMenu(
          label: 'Поиск',
          menus: [
            PlatformMenuItem(
              label: 'Найти...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
              onSelected: () => context.go('/search'),
            ),
            PlatformMenuItem(
              label: 'Палитра команд...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyK, meta: true),
              onSelected: () => CommandPalette.show(context),
            ),
          ],
        ),
        PlatformMenu(
          label: 'Вид',
          menus: [
            PlatformMenuItem(
              label: 'Библиотека',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyL,
                meta: true,
              ),
              onSelected: () => context.go('/library'),
            ),
            PlatformMenuItem(
              label: 'Загрузки',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyD,
                meta: true,
                shift: true,
              ),
              onSelected: () => context.go('/downloads'),
            ),
            PlatformMenuItem(
              label: 'Настройки',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
              onSelected: () => context.go('/settings'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(24);
}

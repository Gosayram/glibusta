import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/config/app_settings.dart';
import '../../auth/presentation/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Аккаунт'),
          if (authState.isAuthenticated)
            _SettingsTile(
              icon: Icons.person,
              title: authState.session?.name ?? 'Пользователь',
              subtitle: 'Нажмите, чтобы выйти',
              onTap: () => _logout(context, ref),
            )
          else
            _SettingsTile(
              icon: Icons.login,
              title: 'Вход',
              subtitle: 'Войдите для доступа к дополнительным функциям',
              onTap: () => _login(context),
            ),

          const Divider(),
          const _SectionHeader(title: 'Источник'),
          _SettingsTile(
            icon: Icons.language,
            title: 'Базовый URL',
            subtitle: settings.baseUrl,
            onTap: () => _editBaseUrl(context, ref, settings),
          ),
          _SettingsTile(
            icon: Icons.dns,
            title: 'Зеркала',
            subtitle: settings.mirrors.isEmpty
                ? 'Не настроены'
                : '${settings.mirrors.length} зеркал(а)',
            onTap: () => _editMirrors(context, ref, settings),
          ),

          const Divider(),
          const _SectionHeader(title: 'Загрузки'),
          _SettingsTile(
            icon: Icons.speed,
            title: 'Параллельные загрузки',
            subtitle: '${settings.maxConcurrentDownloads}',
            onTap: () => _editMaxConcurrent(context, ref, settings),
          ),

          const Divider(),
          const _SectionHeader(title: 'Отображение'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Тёмная тема'),
            subtitle: const Text('Использовать тёмную тему'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (_) {},
          ),

          const Divider(),
          const _SectionHeader(title: 'О приложении'),
          const _SettingsTile(
            icon: Icons.info_outline,
            title: 'Версия',
            subtitle: '0.1.0+1',
          ),
          _SettingsTile(
            icon: Icons.keyboard,
            title: 'Горячие клавиши',
            subtitle: 'Список сочетаний клавиш',
            onTap: () => _showShortcuts(context),
          ),
        ],
      ),
    );
  }

  void _showShortcuts(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Горячие клавиши'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShortcutRow(shortcut: '⌘ + 1', action: 'Главная'),
              _ShortcutRow(shortcut: '⌘ + F', action: 'Поиск'),
              _ShortcutRow(shortcut: '⌘ + L', action: 'Библиотека'),
              _ShortcutRow(shortcut: '⌘ + ⇧ + D', action: 'Загрузки'),
              _ShortcutRow(shortcut: '⌘ + ,', action: 'Настройки'),
              _ShortcutRow(shortcut: '→', action: 'Следующая страница'),
              _ShortcutRow(shortcut: '←', action: 'Предыдущая страница'),
              _ShortcutRow(shortcut: '+', action: 'Увеличить шрифт'),
              _ShortcutRow(shortcut: '-', action: 'Уменьшить шрифт'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }

  void _login(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const LoginScreen(),
        ),
      ),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Выход'),
          content: const Text('Вы уверены, что хотите выйти?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                unawaited(
                  ref.read(authStateProvider.notifier).logout(
                    ref.read(authRepositoryProvider),
                  ),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Выйти'),
            ),
          ],
        ),
      ),
    );
  }

  void _editBaseUrl(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final controller = TextEditingController(text: settings.baseUrl);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Базовый URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'https://example.com'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                ref.read(appSettingsProvider.notifier).state = settings.copyWith(
                  baseUrl: controller.text,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _editMirrors(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final controller = TextEditingController(
      text: settings.mirrors.join('\n'),
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Зеркала (по одному на строку)'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'https://mirror1.example.com\nhttps://mirror2.example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final mirrors = controller.text
                    .split('\n')
                    .map((String l) => l.trim())
                    .where((String l) => l.isNotEmpty)
                    .toList();
                ref.read(appSettingsProvider.notifier).state = settings.copyWith(mirrors: mirrors);
                Navigator.of(context).pop();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _editMaxConcurrent(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => SimpleDialog(
          title: const Text('Параллельные загрузки'),
          children: [1, 2, 3, 5, 10].map((int n) {
            return SimpleDialogOption(
              onPressed: () {
                ref.read(appSettingsProvider.notifier).state = settings.copyWith(
                  maxConcurrentDownloads: n,
                );
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  if (n == settings.maxConcurrentDownloads)
                    const Icon(Icons.check, size: 20)
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 12),
                  Text('$n'),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String action;

  const _ShortcutRow({required this.shortcut, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(action)),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/config/app_settings.dart';
import '../../../core/connectivity/offline_mode.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/content_safety_service.dart';
import '../../../core/storage/storage_bridge_impl.dart';
import '../../../core/storage/storage_mode.dart';
import '../../../core/storage/storage_settings_provider.dart';
import '../../auth/presentation/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final authData = ref.watch(authStateProvider).value;
    final isAuthenticated = authData?.isAuthenticated ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Аккаунт'),
          if (isAuthenticated)
            _SettingsTile(
              icon: Icons.person,
              title: authData?.session?.name ?? 'Пользователь',
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
          SwitchListTile(
            secondary: const Icon(Icons.cell_tower),
            title: const Text(
              'Скачивать через мобильную сеть',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text(
              'По умолчанию только Wi-Fi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: ref.watch(allowMobileDownloadsProvider),
            onChanged: (v) => ref.read(allowMobileDownloadsProvider.notifier).update(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle),
            title: const Text(
              'Авто-продолжение при Wi-Fi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text(
              'Возобновлять загрузки при появлении сети',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: ref.watch(autoResumeOnWifiProvider),
            onChanged: (v) => ref.read(autoResumeOnWifiProvider.notifier).update(v),
          ),

          const Divider(),
          const _SectionHeader(title: 'Хранилище библиотеки'),
          _buildStorageModeTile(context, ref),
          _SettingsTile(
            icon: Icons.folder_copy_outlined,
            title: 'Управление папками',
            subtitle: 'Сохранённые папки и доступ',
            onTap: () => _showPersistedUrisDialog(context),
          ),
          _SettingsTile(
            icon: Icons.storage,
            title: 'Управление хранилищем',
            subtitle: 'Размер данных, очистка кеша',
            onTap: () => context.push('/settings/storage'),
          ),
          _SettingsTile(
            icon: Icons.label,
            title: 'Теги',
            subtitle: 'Управление тегами книг',
            onTap: () => context.push('/settings/tags'),
          ),

          const Divider(),
          const _SectionHeader(title: 'Отображение'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Тёмная тема', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: const Text(
              'Использовать тёмную тему',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (value) {
              ref
                  .read(themeModeProvider.notifier)
                  .setMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Фильтр контента',
            subtitle: 'Настройка безопасности',
            onTap: () => _showContentSafety(context),
          ),
          _SettingsTile(
            icon: Icons.font_download,
            title: 'Шрифты',
            subtitle: 'Скачать дополнительные шрифты',
            onTap: () => context.push('/settings/fonts'),
          ),

          const Divider(),
          const _SectionHeader(title: 'Данные'),
          _SettingsTile(
            icon: Icons.upload_file,
            title: 'Экспорт данных',
            subtitle: 'Сохранить закладки, заметки, цитаты, коллекции',
            onTap: () => _exportData(context),
          ),
          _SettingsTile(
            icon: Icons.download,
            title: 'Импорт данных',
            subtitle: 'Восстановить из файла резервной копии',
            onTap: () => _importData(context),
          ),

          const Divider(),
          const _SectionHeader(title: 'О приложении'),
          const _VersionTile(),
          _SettingsTile(
            icon: Icons.keyboard,
            title: 'Горячие клавиши',
            subtitle: 'Список сочетаний клавиш',
            onTap: () => _showShortcuts(context),
          ),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Диагностика',
            subtitle: 'Информация для отладки',
            onTap: () => context.push('/settings/diagnostics'),
          ),
        ],
      ),
    );
  }

  void _showContentSafety(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<ContentSafetyLevel>(
            future: ContentSafetyService.load(),
            builder: (context, snapshot) {
              final current = snapshot.data ?? ContentSafetyLevel.standard;
              return AlertDialog(
                title: const Text('Фильтр контента'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ContentSafetyLevel.values.map((level) {
                    return ListTile(
                      leading: Icon(
                        level == current ? Icons.check_circle : Icons.circle_outlined,
                        color: level == current ? Theme.of(context).colorScheme.primary : null,
                      ),
                      title: Text(level.displayName),
                      subtitle: Text(level.description),
                      onTap: () {
                        unawaited(ContentSafetyService.save(level));
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
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

  Future<void> _exportData(BuildContext context) async {
    try {
      final db = ref.read(databaseProvider);
      final info = await PackageInfo.fromPlatform();
      final backupService = BackupService(
        db: db,
        appVersion: '${info.version}+${info.buildNumber}',
      );
      final json = await backupService.exportData();
      // TODO: Use file picker or share to save the JSON
      if (kDebugMode) {
        debugPrint('Exported data: ${json.length} bytes');
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные экспортированы')),
      );
    } on Exception catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Импорт данных'),
        content: const Text(
          'Внимание! Текущие данные будут заменены импортированными. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      final db = ref.read(databaseProvider);
      final info = await PackageInfo.fromPlatform();
      final backupService = BackupService(
        db: db,
        appVersion: '${info.version}+${info.buildNumber}',
      );
      final json = await File(filePath).readAsString();
      final importResult = await backupService.importData(json);

      if (!context.mounted) return;

      if (importResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Импортировано: ${importResult.progressImported} прогрессов, '
              '${importResult.bookmarksImported} закладок, '
              '${importResult.notesImported} заметок, '
              '${importResult.quotesImported} цитат',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${importResult.error}')),
        );
      }
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $e')),
      );
    }
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
                  ref.read(authStateProvider.notifier).logout(),
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
                ref.read(appSettingsControllerProvider.notifier).updateBaseUrl(controller.text);
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
      text: settings.customMirrors.join('\n'),
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Зеркала'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.defaultMirrors.isNotEmpty) ...[
                  const Text(
                    'Зеркала из конфигурации (только чтение):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: settings.defaultMirrors.map((m) {
                      return Chip(
                        avatar: const Icon(Icons.lock, size: 16),
                        label: Text(m, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Пользовательские зеркала (по одному на строку):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'https://mirror1.example.com\nhttps://mirror2.example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                ref.read(appSettingsControllerProvider.notifier).updateCustomMirrors(mirrors);
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
                ref.read(appSettingsControllerProvider.notifier).updateMaxConcurrentDownloads(n);
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

  Widget _buildStorageModeTile(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(storageModeProvider);
    final folder = ref.watch(externalFolderProvider);

    final modeLabels = {
      StorageMode.internal: 'Внутренняя библиотека',
      StorageMode.downloads: 'Downloads/Glibusta',
      StorageMode.external: 'Выбранная папка',
    };

    final subtitles = {
      StorageMode.internal: 'Стабильный режим, файлы в sandbox приложения',
      StorageMode.downloads: 'Доступна из файлового менеджера',
      StorageMode.external: folder.name ?? 'Папка не выбрана',
    };

    return ListTile(
      leading: const Icon(Icons.folder),
      title: const Text('Хранилище', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitles[mode]!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showStorageModeDialog(context, ref, mode, modeLabels),
      dense: true,
      minLeadingWidth: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _showStorageModeDialog(
    BuildContext context,
    WidgetRef ref,
    StorageMode currentMode,
    Map<StorageMode, String> modeLabels,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Режим хранилища'),
        children: StorageMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(ref.read(storageModeProvider.notifier).updateMode(mode));
              if (mode == StorageMode.downloads || mode == StorageMode.external) {
                unawaited(_pickFolder(this.context, ref, mode));
              }
            },
            child: Row(
              children: [
                Icon(
                  mode == currentMode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: mode == currentMode ? Theme.of(context).colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Text(modeLabels[mode]!),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref, StorageMode mode) async {
    final folder = ref.read(externalFolderProvider);
    if (folder.uri != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Текущая папка: ${folder.name ?? folder.uri}'),
          action: SnackBarAction(
            label: 'Выбрать другую',
            onPressed: () => _doPickFolder(context, ref, mode),
          ),
        ),
      );
    } else {
      await _doPickFolder(context, ref, mode);
    }
  }

  Future<void> _doPickFolder(BuildContext context, WidgetRef ref, StorageMode mode) async {
    try {
      final bridge = ref.read(storageBridgeProvider);
      final uri = await bridge.pickFolder();
      if (uri == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выбор папки отменён')),
          );
        }
        return;
      }

      final scanned = await bridge.scanBooks(uri);
      final name = uri.split('/').last;

      await ref.read(externalFolderProvider.notifier).updateFolder(uri: uri, name: name);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Найдено книг: ${scanned.length}')),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _showPersistedUrisDialog(BuildContext context) async {
    final bridge = ref.read(storageBridgeProvider);
    final uris = await bridge.getPersistedUris();
    final currentFolder = ref.read(externalFolderProvider);

    if (!context.mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Сохранённые папки'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: uris.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Нет сохранённых папок'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: uris.length,
                          itemBuilder: (context, index) {
                            final uri = uris[index];
                            final name = uri == currentFolder.uri
                                ? '${currentFolder.name ?? uri} (активна)'
                                : uri.split('/').last;
                            final isActive = uri == currentFolder.uri;
                            return ListTile(
                              leading: Icon(
                                isActive ? Icons.folder_open : Icons.folder_outlined,
                                color: isActive ? Theme.of(context).colorScheme.primary : null,
                              ),
                              title: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                uri,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Забыть',
                                onPressed: () async {
                                  final ok = await bridge.forgetUri(uri);
                                  if (ok) {
                                    setDialogState(() {
                                      uris.removeAt(index);
                                    });
                                    if (isActive) {
                                      await ref.read(externalFolderProvider.notifier).clearFolder();
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Закрыть'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                    onPressed: () async {
                      final uri = await bridge.pickFolder();
                      if (uri != null && context.mounted) {
                        final scanned = await bridge.scanBooks(uri);
                        final name = uri.split('/').last;
                        await ref
                            .read(externalFolderProvider.notifier)
                            .updateFolder(uri: uri, name: name);
                        setDialogState(() {
                          if (!uris.contains(uri)) uris.add(uri);
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Найдено книг: ${scanned.length}')),
                          );
                        }
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
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
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      dense: true,
      minLeadingWidth: 20,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Версия'),
            subtitle: Text('Неизвестно'),
          );
        }
        final info = snapshot.data;
        final version = info != null ? '${info.version}+${info.buildNumber}' : '...';
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Версия'),
          subtitle: Text(version),
        );
      },
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

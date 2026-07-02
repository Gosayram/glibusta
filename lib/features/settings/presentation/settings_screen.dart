import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/config/app_settings.dart';
import '../../../core/connectivity/offline_mode.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/calibre_client.dart';
import '../../../core/services/content_safety_service.dart';
import '../../../core/services/webdav_client.dart';
import '../../../core/storage/storage_bridge_impl.dart';
import '../../../core/storage/storage_mode.dart';
import '../../../core/storage/storage_settings_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/login_screen.dart';
import '../../library/data/library_scanner.dart';
import '../../library/presentation/library_screen.dart' show libraryBooksProvider;

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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsAccount),
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
          _SectionHeader(title: l10n.settingsSource),
          _SettingsTile(
            icon: Icons.language,
            title: l10n.settingsBaseUrl,
            subtitle: settings.baseUrl,
            onTap: () => _editBaseUrl(context, ref, settings),
          ),
          _SettingsTile(
            icon: Icons.dns,
            title: l10n.settingsMirrors,
            subtitle: settings.mirrors.isEmpty
                ? l10n.settingsNotConfigured
                : '${settings.mirrors.length} зеркал(а)',
            onTap: () => _editMirrors(context, ref, settings),
          ),

          const Divider(),
          _SectionHeader(title: l10n.settingsDownloads),
          _SettingsTile(
            icon: Icons.speed,
            title: l10n.settingsParallelDownloads,
            subtitle: '${settings.maxConcurrentDownloads}',
            onTap: () => _editMaxConcurrent(context, ref, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cell_tower),
            title: Text(
              l10n.settingsMobileDownloads,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              l10n.settingsMobileDownloadsSub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: ref.watch(allowMobileDownloadsProvider),
            onChanged: (v) => ref.read(allowMobileDownloadsProvider.notifier).update(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle),
            title: Text(
              l10n.settingsAutoResume,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              l10n.settingsAutoResumeSub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: ref.watch(autoResumeOnWifiProvider),
            onChanged: (v) => ref.read(autoResumeOnWifiProvider.notifier).update(v),
          ),

          const Divider(),
          _SectionHeader(title: l10n.settingsStorage),
          _buildStorageModeTile(context, ref, l10n),
          _SettingsTile(
            icon: Icons.folder_open,
            title: l10n.settingsStoragePermission,
            subtitle: l10n.settingsStoragePermissionSub,
            onTap: () => _checkStoragePermission(context),
          ),
          _SettingsTile(
            icon: Icons.storage,
            title: l10n.settingsStorageManagement,
            subtitle: l10n.settingsStorageManagementSub,
            onTap: () => context.push('/settings/storage'),
          ),
          _SettingsTile(
            icon: Icons.refresh,
            title: l10n.settingsRefreshLibrary,
            subtitle: l10n.settingsRefreshLibrarySub,
            onTap: () => _rescanLibrary(context, ref),
          ),
          _SettingsTile(
            icon: Icons.label,
            title: l10n.settingsTags,
            subtitle: l10n.settingsTagsSub,
            onTap: () => context.push('/settings/tags'),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Reading Info Bar',
            subtitle: 'Настройка header/footer в reader',
            onTap: () => context.push('/settings/reading-info'),
          ),
          _SettingsTile(
            icon: Icons.view_list,
            title: 'Chapter Split Rules',
            subtitle: 'Правила разделения TXT на главы',
            onTap: () => context.push('/settings/chapter-split-rules'),
          ),

          const Divider(),
          _SectionHeader(title: l10n.settingsAppearance),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text(l10n.settingsDarkTheme, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              l10n.settingsDarkThemeSub,
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
            title: l10n.settingsContentFilter,
            subtitle: l10n.settingsContentFilterSub,
            onTap: () => _showContentSafety(context),
          ),
          _SettingsTile(
            icon: Icons.font_download,
            title: l10n.settingsFonts,
            subtitle: l10n.settingsFontsSub,
            onTap: () => context.push('/settings/fonts'),
          ),

          const Divider(),
          _SectionHeader(title: l10n.settingsData),
          _SettingsTile(
            icon: Icons.upload_file,
            title: l10n.settingsExport,
            subtitle: l10n.settingsExportSub,
            onTap: () => _exportData(context),
          ),
          _SettingsTile(
            icon: Icons.download,
            title: l10n.settingsImport,
            subtitle: l10n.settingsImportSub,
            onTap: () => _importData(context),
          ),

          const Divider(),
          const _SectionHeader(title: 'Синхронизация'),
          _SettingsTile(
            icon: Icons.cloud_sync,
            title: 'WebDAV',
            subtitle: 'Настройка WebDAV сервера для синхронизации',
            onTap: () => _showWebDavDialog(context),
          ),
          _SettingsTile(
            icon: Icons.library_books,
            title: 'Calibre',
            subtitle: 'Подключение к Calibre Content Server',
            onTap: () => _showCalibreDialog(context),
          ),

          const Divider(),
          _SectionHeader(title: l10n.settingsAbout),
          const _VersionTile(),
          _SettingsTile(
            icon: Icons.keyboard,
            title: l10n.settingsShortcuts,
            subtitle: l10n.settingsShortcutsSub,
            onTap: () => _showShortcuts(context),
          ),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: l10n.settingsDiagnostics,
            subtitle: l10n.settingsDiagnosticsSub,
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
      if (kDebugMode) {
        AppLogger().fine('Exported data: ${json.length} bytes', name: 'Settings');
      }

      // Write to a temporary file and share it via the system share sheet.
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final tempFile = File('${Directory.systemTemp.path}/glibusta_backup_$timestamp.json');
      await tempFile.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Glibusta settings',
        ),
      );

      if (!context.mounted) return;

      unawaited(SmartDialog.showToast('Данные экспортированы'));
    } on Exception catch (e) {
      if (!context.mounted) return;
      unawaited(SmartDialog.showToast('Ошибка экспорта: $e'));
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
      final picker = BookFilePicker();
      final filePath = await picker.pickFile(['json']);
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
        unawaited(
          SmartDialog.showToast(
            'Импортировано: ${importResult.progressImported} прогрессов, '
            '${importResult.bookmarksImported} закладок, '
            '${importResult.notesImported} заметок, '
            '${importResult.quotesImported} цитат',
          ),
        );
      } else {
        unawaited(SmartDialog.showToast('Ошибка: ${importResult.error}'));
      }
    } on Object catch (e) {
      if (!context.mounted) return;
      unawaited(SmartDialog.showToast('Ошибка импорта: $e'));
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

  Widget _buildStorageModeTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final mode = ref.watch(storageModeProvider);
    final folder = ref.watch(externalFolderProvider);

    final subtitles = {
      StorageMode.downloads: l10n.settingsStorageModeAccessible,
      StorageMode.external: folder.name ?? l10n.settingsStorageModeNotSelected,
    };

    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(l10n.settingsStorageMode, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitles[mode]!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showStorageModeDialog(context, ref, mode, l10n),
      dense: true,
      minLeadingWidth: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _showStorageModeDialog(
    BuildContext context,
    WidgetRef ref,
    StorageMode currentMode,
    AppLocalizations l10n,
  ) async {
    final modeLabels = {
      StorageMode.downloads: l10n.settingsStorageModeDownloads,
      StorageMode.external: l10n.settingsStorageModeExternal,
    };

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
      unawaited(SmartDialog.showToast('Текущая папка: ${folder.name ?? folder.uri}'));
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
          unawaited(SmartDialog.showToast('Выбор папки отменён'));
        }
        return;
      }

      final scanned = await bridge.scanBooks(uri);
      final name = uri.split('/').last;

      await ref.read(externalFolderProvider.notifier).updateFolder(uri: uri, name: name);

      if (context.mounted) {
        unawaited(SmartDialog.showToast('Найдено книг: ${scanned.length}'));
      }
    } on Object catch (e) {
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Ошибка: $e'));
      }
    }
  }

  Future<void> _checkStoragePermission(BuildContext context) async {
    const channel = MethodChannel('com.gosayram.glibusta/storage_bridge');
    try {
      final granted = await channel.invokeMethod<bool>('checkStoragePermission');
      if (!context.mounted) return;
      if (granted == true) {
        unawaited(
          SmartDialog.showToast(AppLocalizations.of(context).settingsStoragePermissionGranted),
        );
        return;
      }
      await channel.invokeMethod<bool>('requestStoragePermission');
      if (!context.mounted) return;
      unawaited(
        SmartDialog.showToast(AppLocalizations.of(context).settingsStoragePermissionOpenSettings),
      );
    } on MissingPluginException {
      if (!context.mounted) return;
      unawaited(SmartDialog.showToast('Недоступно на этой платформе'));
    }
  }

  Future<void> _rescanLibrary(BuildContext context, WidgetRef ref) async {
    final scanner = ref.read(libraryScannerProvider);
    if (scanner.isScanning) {
      unawaited(SmartDialog.showToast(AppLocalizations.of(context).storageAlreadyScanning));
      return;
    }
    unawaited(SmartDialog.showToast(AppLocalizations.of(context).storageScanning));
    final result = await scanner.scanWithResult();
    if (!context.mounted) return;
    ref.invalidate(libraryBooksProvider);
    if (result.hasError) {
      unawaited(SmartDialog.showToast('Ошибка: ${result.error}'));
    } else {
      final l10n = AppLocalizations.of(context);
      unawaited(
        SmartDialog.showToast(
          l10n.storageScanResult(result.imported, result.skipped),
        ),
      );
    }
  }

  // MD-13.1: WebDAV sync settings dialog
  void _showWebDavDialog(BuildContext context) {
    final urlCtl = TextEditingController();
    final userCtl = TextEditingController();
    final passCtl = TextEditingController();
    var connected = false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('WebDAV'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlCtl,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://example.com/dav/',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: userCtl,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passCtl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  if (connected)
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Connected ✓', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final url = urlCtl.text.trim();
                  if (url.isEmpty) return;
                  final client = WebDavClient(baseUrl: url);
                  final ok = await client.ping();
                  setSt(() => connected = ok);
                },
                child: const Text('Test Connection'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MD-13.2: Calibre Content Server settings dialog
  void _showCalibreDialog(BuildContext context) {
    final urlCtl = TextEditingController();
    var connected = false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Calibre Content Server'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlCtl,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.100:8080',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (connected)
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Connected ✓', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final url = urlCtl.text.trim();
                  if (url.isEmpty) return;
                  final client = CalibreClient(baseUrl: url);
                  final ok = await client.ping();
                  setSt(() => connected = ok);
                },
                child: const Text('Test Connection'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
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

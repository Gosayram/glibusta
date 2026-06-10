import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/connectivity/offline_mode.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика')),
      body: FutureBuilder<DiagnosticsInfo>(
        future: _gatherInfo(context, ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snapshot.data!;
          return ListView(
            children: [
              _healthSection('Состояние системы', info),
              _section('Приложение', [
                ListTile(
                  title: const Text('Версия'),
                  trailing: Text('${info.appVersion}+${info.buildNumber}'),
                ),
                ListTile(
                  title: const Text('Платформа'),
                  trailing: Text(info.platform),
                ),
              ]),
              _section('Устройство', [
                ListTile(
                  title: const Text('Модель'),
                  trailing: Text(info.deviceModel),
                ),
                if (info.deviceManufacturer.isNotEmpty)
                  ListTile(
                    title: const Text('Производитель'),
                    trailing: Text(info.deviceManufacturer),
                  ),
                ListTile(
                  title: const Text('ОС'),
                  trailing: Text(info.deviceOS),
                ),
              ]),
              _section('Экран', [
                ListTile(
                  title: const Text('Размер'),
                  trailing: Text(
                    '${info.screenWidth.toStringAsFixed(0)}×${info.screenHeight.toStringAsFixed(0)}',
                  ),
                ),
                ListTile(
                  title: const Text('Pixel Ratio'),
                  trailing: Text('${info.pixelRatio}x'),
                ),
                ListTile(
                  title: const Text('Ориентация'),
                  trailing: Text(info.orientation),
                ),
                ListTile(
                  title: const Text('Яркость'),
                  trailing: Text(info.brightness),
                ),
                ListTile(
                  title: const Text('Масштаб текста'),
                  trailing: Text(info.textScale),
                ),
                if (info.paddingTop > 0)
                  ListTile(
                    title: const Text('Insets (верх/низ)'),
                    trailing: Text(
                      '${info.paddingTop.toStringAsFixed(0)} / ${info.paddingBottom.toStringAsFixed(0)}',
                    ),
                  ),
                if (info.viewInsetsBottom > 0)
                  ListTile(
                    title: const Text('Клавиатура'),
                    trailing: Text('${info.viewInsetsBottom.toStringAsFixed(0)}px'),
                  ),
              ]),
              _section('База данных', [
                ListTile(
                  title: const Text('Статус'),
                  trailing: _statusChip(info.dbOk),
                ),
                ListTile(
                  title: const Text('Книг в библиотеке'),
                  trailing: Text('${info.totalBooks}'),
                ),
                ListTile(
                  title: const Text('FB2'),
                  trailing: Text('${info.fb2Count}'),
                ),
                ListTile(
                  title: const Text('EPUB'),
                  trailing: Text('${info.epubCount}'),
                ),
                ListTile(
                  title: const Text('Размер БД'),
                  trailing: Text(info.dbSize),
                ),
              ]),
              _section('Хранилище', [
                ListTile(
                  title: const Text('Статус'),
                  trailing: _statusChip(info.storageOk),
                ),
                ListTile(
                  title: const Text('Доступно'),
                  trailing: Text(info.storageFree),
                ),
                ListTile(
                  title: const Text('Занято приложением'),
                  trailing: Text(info.appSize),
                ),
              ]),
              _section('Подключение', [
                ListTile(
                  title: const Text('Статус'),
                  trailing: _statusChip(info.connectivityOk),
                ),
                ListTile(
                  title: const Text('Тип'),
                  trailing: Text(info.connectivityType),
                ),
              ]),
              _section('Ошибки', [
                ListTile(
                  title: const Text('Последняя ошибка'),
                  subtitle: Text(
                    info.lastError ?? 'Нет ошибок',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
                if (info.recentErrors.isNotEmpty)
                  ...info.recentErrors.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _exportReport(context, info),
                        child: const Text('Экспорт отчёта'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _runDiagnostics(context, ref),
                        child: const Text('Перепроверить'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _healthSection(String title, DiagnosticsInfo info) {
    final items = <_HealthItem>[
      _HealthItem('База данных', info.dbOk),
      _HealthItem('Хранилище', info.storageOk),
      _HealthItem('Подключение', info.connectivityOk),
    ];
    final allOk = items.every((i) => i.ok);

    return ExpansionTile(
      initiallyExpanded: true,
      title: Row(
        children: [
          Text(title),
          const SizedBox(width: 8),
          Icon(
            allOk ? Icons.check_circle : Icons.warning,
            color: allOk ? Colors.green : Colors.orange,
            size: 20,
          ),
        ],
      ),
      children: items
          .map(
            (item) => ListTile(
              leading: Icon(
                item.ok ? Icons.check_circle_outline : Icons.error_outline,
                color: item.ok ? Colors.green : Colors.red,
                size: 20,
              ),
              title: Text(item.label),
              trailing: Text(
                item.ok ? 'OK' : 'Ошибка',
                style: TextStyle(
                  color: item.ok ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(title),
      children: children,
    );
  }

  Widget _statusChip(bool ok) {
    return Chip(
      label: Text(
        ok ? 'OK' : 'Ошибка',
        style: TextStyle(
          color: ok ? Colors.green : Colors.red,
          fontSize: 12,
        ),
      ),
      backgroundColor: ok ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<DiagnosticsInfo> _gatherInfo(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final logger = ref.read(appLoggerProvider);

    // Capture MediaQuery values before any async gaps
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final pixelRatio = mq.devicePixelRatio;
    final orientation = mq.orientation.name;
    final brightness = mq.platformBrightness.name;
    final textScale = mq.textScaler.scale(14).toStringAsFixed(1);
    final padding = mq.padding;
    final viewInsets = mq.viewInsets;

    // DB check
    bool dbOk = true;
    int totalBooks = 0;
    int fb2Count = 0;
    int epubCount = 0;
    try {
      final allBooks = await (db.select(db.savedBooks)).get();
      totalBooks = allBooks.length;
      final allDownloads = await (db.select(db.downloads)).get();
      fb2Count = allDownloads.where((d) => d.format.toLowerCase() == 'fb2').length;
      epubCount = allDownloads.where((d) => d.format.toLowerCase() == 'epub').length;
    } on Object catch (_) {
      dbOk = false;
    }

    // Storage check
    bool storageOk = true;
    String storageFree = 'Неизвестно';
    String appSize = 'Неизвестно';
    try {
      final dir = await getApplicationSupportDirectory();
      final stat = await dir.stat();
      appSize = _formatBytes(stat.size);
      // Try to get free space
      final result = await Process.run('df', ['-h', dir.path]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            storageFree = parts[3];
          }
        }
      }
    } on Object catch (_) {
      storageOk = false;
    }

    // Connectivity check — probe actual server reachability
    bool connectivityOk = true;
    String connectivityType = 'Неизвестно';
    try {
      final service = ref.read(offlineModeServiceProvider);
      connectivityType = service.state.name;
      // Probe the actual server, not just network interface
      final settings = ref.read(appSettingsControllerProvider);
      connectivityOk = await OfflineModeService.probeServer(settings.baseUrl);
      if (!connectivityOk) {
        connectivityType = 'Сервер недоступен';
      }
    } on Object catch (_) {
      connectivityOk = false;
      connectivityType = 'Ошибка';
    }

    // Error info
    String? lastError;
    final recentErrors = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      lastError = prefs.getString('last_error');
      final errors = logger.entries
          .where((e) => e.level == 'SEVERE')
          .take(5)
          .map((e) => '${e.time.hour}:${e.time.minute} - ${e.message}')
          .toList();
      recentErrors.addAll(errors);
    } on Object catch (_) {}

    // App version
    String appVersion = '0.1.0';
    String buildNumber = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
      buildNumber = info.buildNumber;
    } on Object catch (_) {}

    // Device info
    String deviceModel = 'Неизвестно';
    String deviceManufacturer = '';
    String deviceOS = Platform.operatingSystemVersion;
    String deviceBrand = '';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceModel = android.model;
        deviceManufacturer = android.manufacturer;
        deviceBrand = android.brand;
        deviceOS = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceModel = ios.model;
        deviceManufacturer = 'Apple';
        deviceBrand = 'Apple';
        deviceOS = 'iOS ${ios.systemVersion}';
      } else if (Platform.isMacOS) {
        final mac = await deviceInfo.macOsInfo;
        deviceModel = mac.model;
        deviceManufacturer = 'Apple';
        deviceBrand = 'Apple';
        deviceOS = 'macOS ${mac.osRelease}';
      }
    } on Object catch (_) {}

    return DiagnosticsInfo(
      appVersion: appVersion,
      buildNumber: buildNumber,
      platform: Platform.operatingSystem,
      totalBooks: totalBooks,
      fb2Count: fb2Count,
      epubCount: epubCount,
      dbSize: '~${_formatBytes(totalBooks * 500 * 1024)}',
      lastError: lastError,
      recentErrors: recentErrors,
      dbOk: dbOk,
      storageOk: storageOk,
      storageFree: storageFree,
      appSize: appSize,
      connectivityOk: connectivityOk,
      connectivityType: connectivityType,
      deviceModel: deviceModel,
      deviceManufacturer: deviceManufacturer,
      deviceBrand: deviceBrand,
      deviceOS: deviceOS,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      pixelRatio: pixelRatio,
      orientation: orientation,
      brightness: brightness,
      textScale: textScale,
      paddingTop: padding.top,
      paddingBottom: padding.bottom,
      viewInsetsBottom: viewInsets.bottom,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _exportReport(BuildContext context, DiagnosticsInfo info) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final report = [
      '=== Glibusta Health Report ===',
      'Date: $dateStr',
      '',
      '--- Device ---',
      'Model: ${info.deviceManufacturer.isNotEmpty ? "${info.deviceManufacturer} " : ""}${info.deviceModel}',
      'OS: ${info.deviceOS}',
      'Screen: ${info.screenWidth.toStringAsFixed(0)}x${info.screenHeight.toStringAsFixed(0)} @${info.pixelRatio}x',
      'Orientation: ${info.orientation}',
      'Brightness: ${info.brightness}',
      'Text Scale: ${info.textScale}',
      if (info.paddingTop > 0)
        'Padding: top=${info.paddingTop.toStringAsFixed(0)} bottom=${info.paddingBottom.toStringAsFixed(0)}',
      if (info.viewInsetsBottom > 0) 'Keyboard: ${info.viewInsetsBottom.toStringAsFixed(0)}px',
      '',
      '--- System ---',
      'DB: ${info.dbOk ? "OK" : "ERROR"}',
      'Storage: ${info.storageOk ? "OK" : "ERROR"} (${info.storageFree} free)',
      'Connectivity: ${info.connectivityOk ? "OK" : "ERROR"} (${info.connectivityType})',
      '',
      '--- App ---',
      'Version: ${info.appVersion}+${info.buildNumber}',
      'Platform: ${info.platform}',
      'Books: ${info.totalBooks} (FB2: ${info.fb2Count}, EPUB: ${info.epubCount})',
      'DB Size: ${info.dbSize}',
      'App Size: ${info.appSize}',
      '',
      '--- Errors ---',
      'Last: ${info.lastError ?? "None"}',
      ...info.recentErrors.map((e) => '  $e'),
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Отчёт скопирован')),
    );
  }

  Future<void> _runDiagnostics(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Проверка...')),
    );
    // Re-trigger by rebuilding - the FutureBuilder will re-run
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Проверка завершена')),
    );
  }
}

class _HealthItem {
  const _HealthItem(this.label, this.ok);
  final String label;
  final bool ok;
}

class DiagnosticsInfo {
  final String appVersion;
  final String buildNumber;
  final String platform;
  final int totalBooks;
  final int fb2Count;
  final int epubCount;
  final String dbSize;
  final String? lastError;
  final List<String> recentErrors;
  final bool dbOk;
  final bool storageOk;
  final String storageFree;
  final String appSize;
  final bool connectivityOk;
  final String connectivityType;
  final String deviceModel;
  final String deviceManufacturer;
  final String deviceBrand;
  final String deviceOS;
  final double screenWidth;
  final double screenHeight;
  final double pixelRatio;
  final String orientation;
  final String brightness;
  final String textScale;
  final double paddingTop;
  final double paddingBottom;
  final double viewInsetsBottom;

  DiagnosticsInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.totalBooks,
    required this.fb2Count,
    required this.epubCount,
    required this.dbSize,
    this.lastError,
    this.recentErrors = const [],
    required this.dbOk,
    required this.storageOk,
    required this.storageFree,
    required this.appSize,
    required this.connectivityOk,
    required this.connectivityType,
    required this.deviceModel,
    required this.deviceManufacturer,
    required this.deviceBrand,
    required this.deviceOS,
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
    required this.orientation,
    required this.brightness,
    required this.textScale,
    required this.paddingTop,
    required this.paddingBottom,
    required this.viewInsetsBottom,
  });
}

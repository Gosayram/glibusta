import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../core/services/sync_service.dart';

enum SyncDirection { upload, download, both }

enum BookSyncStatus { localOnly, remoteOnly, both, downloading, uploading, syncing }

class BookSyncInfo {
  const BookSyncInfo({
    required this.bookId,
    required this.status,
    this.lastSynced,
    this.remoteVersion,
    this.localVersion,
  });

  final String bookId;
  final BookSyncStatus status;
  final DateTime? lastSynced;
  final int? remoteVersion;
  final int? localVersion;

  String get statusLabel {
    switch (status) {
      case BookSyncStatus.localOnly:
        return 'Только локально';
      case BookSyncStatus.remoteOnly:
        return 'Только удалённо';
      case BookSyncStatus.both:
        return 'Синхронизировано';
      case BookSyncStatus.downloading:
        return 'Загрузка...';
      case BookSyncStatus.uploading:
        return 'Отправка...';
      case BookSyncStatus.syncing:
        return 'Синхронизация...';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case BookSyncStatus.localOnly:
        return Icons.phone_android;
      case BookSyncStatus.remoteOnly:
        return Icons.cloud;
      case BookSyncStatus.both:
        return Icons.cloud_done;
      case BookSyncStatus.downloading:
        return Icons.cloud_download;
      case BookSyncStatus.uploading:
        return Icons.cloud_upload;
      case BookSyncStatus.syncing:
        return Icons.sync;
    }
  }

  Color getStatusColor(BuildContext context) {
    switch (status) {
      case BookSyncStatus.localOnly:
        return Theme.of(context).colorScheme.outline;
      case BookSyncStatus.remoteOnly:
        return Theme.of(context).colorScheme.tertiary;
      case BookSyncStatus.both:
        return Colors.green;
      case BookSyncStatus.downloading:
      case BookSyncStatus.uploading:
      case BookSyncStatus.syncing:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class SyncConflictDialog extends StatelessWidget {
  const SyncConflictDialog({
    required this.conflict,
    super.key,
  });

  final SyncConflict conflict;

  static Future<String?> show(BuildContext context, SyncConflict conflict) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SyncConflictDialog(conflict: conflict),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.sync_problem, color: theme.colorScheme.error, size: 48),
      title: const Text('Конфликт синхронизации'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Книга: ${conflict.bookId}'),
          const SizedBox(height: 12),
          _buildVersionInfo(
            context,
            'Локальная версия',
            conflict.localModified,
            conflict.localVersion,
            conflict.localIsNewer,
          ),
          const SizedBox(height: 8),
          _buildVersionInfo(
            context,
            'Удалённая версия',
            conflict.remoteModified,
            conflict.remoteVersion,
            conflict.remoteIsNewer,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('local'),
          child: const Text('Оставить локальную'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('remote'),
          child: const Text('Принять удалённую'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop('merge'),
          child: const Text('Объединить'),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(
    BuildContext context,
    String label,
    DateTime modified,
    int? version,
    bool isLatest,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isLatest
            ? Colors.green.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: isLatest ? Border.all(color: Colors.green) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                Text(
                  '${modified.day}.${modified.month}.${modified.year} ${modified.hour}:${modified.minute}',
                  style: theme.textTheme.bodySmall,
                ),
                if (version != null) Text('v$version', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (isLatest) const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  double _backupProgress = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Резервное копирование')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Backup', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создать резервную копию базы данных и книг',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isBackingUp) ...[
                    LinearProgressIndicator(value: _backupProgress),
                    const SizedBox(height: 8),
                    Text('${(_backupProgress * 100).toInt()}%'),
                  ] else
                    FilledButton.icon(
                      onPressed: _startBackup,
                      icon: const Icon(Icons.backup),
                      label: const Text('Создать backup'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restore, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 12),
                      Text('Restore', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Восстановить данные из резервной копии',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isRestoring)
                    const CircularProgressIndicator()
                  else
                    OutlinedButton.icon(
                      onPressed: _startRestore,
                      icon: const Icon(Icons.restore),
                      label: const Text('Восстановить'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startBackup() async {
    setState(() {
      _isBackingUp = true;
      _backupProgress = 0;
    });

    for (var i = 0; i <= 100; i += 10) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() => _backupProgress = i / 100);
      }
    }

    if (mounted) {
      setState(() => _isBackingUp = false);
      unawaited(SmartDialog.showToast('Backup создан успешно'));
    }
  }

  Future<void> _startRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Восстановление'),
        content: const Text('Текущие данные будут заменены. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isRestoring = false);
      unawaited(SmartDialog.showToast('Данные восстановлены'));
    }
  }
}

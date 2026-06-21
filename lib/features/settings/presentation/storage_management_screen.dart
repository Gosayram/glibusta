import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../core/platform/app_file_storage.dart';
import '../../../core/services/catalog_cover_cache_service.dart';
import '../../../core/services/smart_cleanup_service.dart';
import '../../../core/storage/storage_info_model.dart';

class StorageManagementScreen extends ConsumerStatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  ConsumerState<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends ConsumerState<StorageManagementScreen> {
  bool _isCleaning = false;

  @override
  Widget build(BuildContext context) {
    final storageAsync = ref.watch(storageInfoProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление хранилищем'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(storageInfoProvider),
          ),
        ],
      ),
      body: storageAsync.when(
        data: (StorageInfoModel info) => ListView(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Всего: ${info.totalHuman}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final cat in info.categories)
                      _StorageBar(
                        name: cat.name,
                        sizeHuman: cat.sizeHuman,
                        fraction: info.totalBytes > 0 ? cat.sizeBytes / info.totalBytes : 0,
                        color: _colorForIcon(cat.icon, theme),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Действия',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.cleaning_services,
              title: 'Очистить временные файлы',
              subtitle: 'Файлы старше 1 часа',
              onTap: _cleanTemp,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.delete_sweep,
              title: 'Очистить кеш',
              subtitle: 'Файлы кеша старше 7 дней',
              onTap: _cleanCache,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.find_in_page,
              title: 'Найти сиротские файлы',
              subtitle: 'Файлы книг без записи в БД',
              onTap: _findOrphans,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.fitness_center,
              title: 'Тяжёлые книги',
              subtitle: 'Книги больше 5 МБ',
              onTap: _findHeavyBooks,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.image_not_supported,
              title: 'Очистить кеш обложек каталога',
              subtitle: 'Удалить все кешированные обложки',
              onTap: _cleanCatalogCovers,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.timer,
              title: 'Очистить устаревшие обложки',
              subtitle: 'Обложки старше 30 дней',
              onTap: _cleanExpiredCatalogCovers,
              enabled: !_isCleaning,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }

  Color _colorForIcon(String icon, ThemeData theme) {
    switch (icon) {
      case 'database':
        return theme.colorScheme.primary;
      case 'book':
        return theme.colorScheme.secondary;
      case 'image':
        return theme.colorScheme.tertiary;
      case 'catalog':
        return Colors.orange;
      case 'cache':
        return Colors.teal;
      case 'temp':
        return Colors.grey;
      default:
        return theme.colorScheme.primary;
    }
  }

  Future<void> _cleanTemp() async {
    setState(() => _isCleaning = true);
    try {
      final storage = AppFileStorageImpl();
      final tempDir = (await storage.tempDir()).path;
      final cleanup = ref.read(smartCleanupServiceProvider);
      final (count, bytes) = await cleanup.cleanupTempFiles(tempDir);
      if (!mounted) return;
      unawaited(SmartDialog.showToast('Удалено $count файлов (${formatBytes(bytes)})'));
      ref.invalidate(storageInfoProvider);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _cleanCache() async {
    setState(() => _isCleaning = true);
    try {
      final storage = AppFileStorageImpl();
      final cacheDir = (await storage.cacheDir()).path;
      final cleanup = ref.read(smartCleanupServiceProvider);
      final count = await cleanup.cleanupCacheFiles(cacheDir);
      if (!mounted) return;
      unawaited(SmartDialog.showToast('Очищено $count файлов кеша'));
      ref.invalidate(storageInfoProvider);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _findOrphans() async {
    setState(() => _isCleaning = true);
    try {
      final storage = AppFileStorageImpl();
      final booksDir = (await storage.booksDir()).path;
      final cleanup = ref.read(smartCleanupServiceProvider);
      final orphans = await cleanup.findOrphanFiles(booksDir);
      if (!mounted) return;
      if (orphans.isEmpty) {
        unawaited(SmartDialog.showToast('Сиротские файлы не найдены'));
      } else {
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text('Сиротские файлы (${orphans.length})'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: orphans.length,
                itemBuilder: (_, int i) => ListTile(
                  dense: true,
                  title: Text(
                    orphans[i].split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(orphans[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _findHeavyBooks() async {
    setState(() => _isCleaning = true);
    try {
      final cleanup = ref.read(smartCleanupServiceProvider);
      final heavy = await cleanup.findHeavyBooks();
      if (!mounted) return;
      if (heavy.isEmpty) {
        unawaited(SmartDialog.showToast('Тяжёлых книг не найдено'));
      } else {
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text('Тяжёлые книги (${heavy.length})'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: heavy.length,
                itemBuilder: (_, int i) => ListTile(
                  dense: true,
                  title: Text(heavy[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(heavy[i].sizeHuman),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _cleanCatalogCovers() async {
    setState(() => _isCleaning = true);
    try {
      final cacheService = ref.read(catalogCoverCacheServiceProvider);
      await cacheService.clearAll();
      if (!mounted) return;
      unawaited(SmartDialog.showToast('Кеш обложек каталога очищен'));
      ref.invalidate(storageInfoProvider);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _cleanExpiredCatalogCovers() async {
    setState(() => _isCleaning = true);
    try {
      final cacheService = ref.read(catalogCoverCacheServiceProvider);
      await cacheService.clearExpired();
      if (!mounted) return;
      unawaited(SmartDialog.showToast('Устаревшие обложки удалены'));
      ref.invalidate(storageInfoProvider);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({
    required this.name,
    required this.sizeHuman,
    required this.fraction,
    required this.color,
  });

  final String name;
  final String sizeHuman;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              sizeHuman,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: enabled ? onTap : null,
      dense: true,
      enabled: enabled,
    );
  }
}

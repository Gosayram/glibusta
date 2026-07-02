import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../core/platform/app_file_storage.dart';
import '../../../core/services/catalog_cover_cache_service.dart';
import '../../../core/services/smart_cleanup_service.dart';
import '../../../core/storage/storage_info_model.dart';
import '../../../l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageTitle),
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
                      l10n.storageTotal(info.totalHuman),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.storageActions,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.cleaning_services,
              title: l10n.storageCleanTemp,
              subtitle: l10n.storageCleanTempSub,
              onTap: _cleanTemp,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.delete_sweep,
              title: l10n.storageCleanCache,
              subtitle: l10n.storageCleanCacheSub,
              onTap: _cleanCache,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.find_in_page,
              title: l10n.storageFindOrphans,
              subtitle: l10n.storageFindOrphansSub,
              onTap: _findOrphans,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.fitness_center,
              title: l10n.storageFindHeavy,
              subtitle: l10n.storageFindHeavySub,
              onTap: _findHeavyBooks,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.image_not_supported,
              title: l10n.storageCleanCatalogCovers,
              subtitle: l10n.storageCleanCatalogCoversSub,
              onTap: _cleanCatalogCovers,
              enabled: !_isCleaning,
            ),
            _ActionTile(
              icon: Icons.timer,
              title: l10n.storageCleanExpiredCovers,
              subtitle: l10n.storageCleanExpiredCoversSub,
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
      case 'download':
        return Colors.blue;
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
      final l10n = AppLocalizations.of(context);
      unawaited(SmartDialog.showToast(l10n.storageTempCleaned(count, formatBytes(bytes))));
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
      final l10n = AppLocalizations.of(context);
      unawaited(SmartDialog.showToast(l10n.storageCacheCleaned(count)));
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
      final l10n = AppLocalizations.of(context);
      if (orphans.isEmpty) {
        unawaited(SmartDialog.showToast(l10n.storageNoOrphans));
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
      final l10n = AppLocalizations.of(context);
      if (heavy.isEmpty) {
        unawaited(SmartDialog.showToast(l10n.storageNoHeavy));
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
      final l10n = AppLocalizations.of(context);
      unawaited(SmartDialog.showToast(l10n.storageCatalogCoversCleaned));
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
      final l10n = AppLocalizations.of(context);
      unawaited(SmartDialog.showToast(l10n.storageExpiredCoversCleaned));
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

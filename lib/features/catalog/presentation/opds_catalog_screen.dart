import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/services/opds_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';

final opdsCatalogsProvider = Provider<List<OpdsCatalog>>((ref) {
  return builtInCatalogs(ref.watch(appSettingsControllerProvider).baseUrl);
});

class OpdsCatalogScreen extends ConsumerStatefulWidget {
  const OpdsCatalogScreen({super.key});

  @override
  ConsumerState<OpdsCatalogScreen> createState() => _OpdsCatalogScreenState();
}

class _OpdsCatalogScreenState extends ConsumerState<OpdsCatalogScreen> {
  final _searchController = TextEditingController();
  List<OpdsEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUrl;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed(String url, {String? username, String? password}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentUrl = url;
    });

    try {
      final service = ref.read(opdsServiceProvider);
      final entries = await service.fetchFeed(url, username: username, password: password);
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = '${l10n.opdsLoadError}: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _search(String query) async {
    if (_currentUrl == null || query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(opdsServiceProvider);
      final entries = await service.search(_currentUrl!, query);
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = '${l10n.opdsSearchError}: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogs = ref.watch(opdsCatalogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Online Catalogs'),
        actions: [
          if (_currentUrl != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCatalogDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_currentUrl != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.catalogSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: _search,
              ),
            ),
          if (_isLoading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: _entries.isEmpty && !_isLoading
                ? _buildCatalogList(catalogs, theme)
                : _buildEntriesList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogList(List<OpdsCatalog> catalogs, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: catalogs.length,
      itemBuilder: (context, index) {
        final catalog = catalogs[index];
        return Card(
          child: ListTile(
            leading: Icon(
              catalog.isBuiltIn ? Icons.language : Icons.bookmark,
              color: theme.colorScheme.primary,
            ),
            title: Text(catalog.name),
            subtitle: Text(catalog.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _loadFeed(catalog.url, username: catalog.username, password: catalog.password),
          ),
        );
      },
    );
  }

  Widget _buildEntriesList(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Card(
          child: ListTile(
            leading: entry.coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: entry.coverUrl!,
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Icon(
                        Icons.book,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(Icons.book, color: theme.colorScheme.primary),
            title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: entry.author != null ? Text(entry.author!, maxLines: 1) : null,
            trailing: entry.downloadUrl != null
                ? IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      unawaited(SmartDialog.showToast('${l10n.loading}: ${entry.title}'));
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showAddCatalogDialog() {
    final l10n = AppLocalizations.of(context);
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    unawaited(
      showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.addCatalog),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: l10n.nameLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: InputDecoration(hintText: l10n.opdsUrlLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  unawaited(_loadFeed(url));
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/opds_service.dart';

final opdsCatalogsProvider = Provider<List<OpdsCatalog>>((ref) {
  return builtInCatalogs;
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
        setState(() {
          _error = 'Ошибка загрузки: $e';
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
        setState(() {
          _error = 'Ошибка поиска: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(opdsCatalogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
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
                  hintText: 'Поиск в каталоге...',
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Загрузка: ${entry.title}')),
                      );
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showAddCatalogDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    unawaited(
      showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Добавить каталог'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Название'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(hintText: 'URL OPDS каталога'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  unawaited(_loadFeed(url));
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}

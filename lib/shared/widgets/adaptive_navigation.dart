import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/adaptive_context.dart';
import '../../core/platform/app_platform.dart';
import '../../features/library/data/book_import_service.dart';
import '../models/book.dart';
import 'book_drop_zone.dart';
import 'macos_right_panel.dart';

class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<NavigationDestination> compactDestinations = [
    NavigationDestination(icon: Icon(Icons.library_books), label: 'Библиотека'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Поиск'),
    NavigationDestination(icon: Icon(Icons.download), label: 'Загрузки'),
    NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
  ];

  static const List<NavigationRailDestination> expandedDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.library_books),
      label: Text('Библиотека'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.search),
      label: Text('Поиск'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.download),
      label: Text('Загрузки'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings),
      label: Text('Настройки'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        animationDuration: const Duration(milliseconds: 300),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: compactDestinations,
      );
    }

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: context.isExpanded,
      labelType: context.isExpanded
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Icon(Icons.menu_book, size: 28),
      ),
      destinations: expandedDestinations,
    );
  }
}

/// macOS-style sidebar navigation
class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({
    super.key,
    this.selectedIndex = 0,
    this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  static const List<_SidebarItem> _items = [
    _SidebarItem(icon: Icons.library_books, label: 'Библиотека', route: '/library'),
    _SidebarItem(icon: Icons.search, label: 'Поиск', route: '/search'),
    _SidebarItem(icon: Icons.download, label: 'Загрузки', route: '/downloads'),
    _SidebarItem(icon: Icons.collections_bookmark, label: 'Коллекции', route: '/collections'),
    _SidebarItem(icon: Icons.sticky_note_2_outlined, label: 'Аннотации', route: '/annotations'),
    _SidebarItem(icon: Icons.bar_chart, label: 'Статистика', route: '/stats'),
    _SidebarItem(icon: Icons.settings, label: 'Настройки', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SizedBox(
        width: 220,
        child: Column(
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book, size: 24, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Glibusta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isSelected = index == selectedIndex;
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? colorScheme.primary : null,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    onTap: () => onDestinationSelected?.call(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}

// ─── Shells ─────────────────────────────────────────────

class MobileShell extends StatelessWidget {
  const MobileShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AdaptiveNavigation(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class TabletShell extends StatelessWidget {
  const TabletShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AdaptiveNavigation(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    );
  }
}

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AdaptiveNavigation(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    );
  }
}

/// macOS-style shell with sidebar
class MacOSShell extends ConsumerWidget {
  const MacOSShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Book? selectedBook = ref.watch(selectedBookForPanelProvider);

    return Scaffold(
      body: BookDropZone(
        onBooksDropped: (paths) => _handleDrop(context, ref, paths),
        child: Row(
          children: [
            SidebarNavigation(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
            if (selectedBook != null) ...[
              const VerticalDivider(width: 1),
              const MacOSRightPanel(),
            ],
          ],
        ),
      ),
    );
  }

  void _handleDrop(BuildContext context, WidgetRef ref, List<String> paths) {
    final epubPaths = paths.where((p) => p.toLowerCase().endsWith('.epub')).toList();
    if (epubPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поддерживаются только .epub файлы')),
      );
      return;
    }
    final importService = ref.read(bookImportServiceProvider);
    for (final path in epubPaths) {
      unawaited(
        importService.importFile(path).then((result) {
          if (!context.mounted) return;
          final msg = result.isSuccess
              ? 'Импортировано: ${result.title}'
              : result.isDuplicate
              ? 'Дубликат: ${result.title}'
              : 'Ошибка: ${result.error}';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }),
      );
    }
  }
}

class ShellWithNav extends ConsumerWidget {
  const ShellWithNav({super.key, this.navigationShell});
  final StatefulNavigationShell? navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(platformCapabilitiesProvider);

    // Fallback for non-StatefulShellRoute routes (catalog, collections, etc.)
    final shell = navigationShell;

    if (capabilities.hasNativeMenuBar) {
      return shell != null
          ? MacOSShell(navigationShell: shell)
          : const Scaffold(body: SizedBox.shrink());
    }

    if (shell == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (context.isCompact) {
      return MobileShell(navigationShell: shell);
    } else if (context.isMedium) {
      return TabletShell(navigationShell: shell);
    } else {
      return DesktopShell(navigationShell: shell);
    }
  }
}

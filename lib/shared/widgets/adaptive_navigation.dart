import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_platform.dart';
import '../../core/utils/app_breakpoints.dart';
import '../models/book.dart';
import 'book_drop_zone.dart';
import 'macos_right_panel.dart';

class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({super.key});

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

  static const List<String> routes = [
    '/library',
    '/search',
    '/downloads',
    '/settings',
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int bestIdx = 0;
    int bestLen = 0;
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      if (location == r || (location.startsWith(r) && r.length > bestLen)) {
        bestIdx = i;
        bestLen = r.length;
      }
    }
    return bestIdx;
  }

  void _onTap(BuildContext context, int index) => context.go(routes[index]);

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppBreakpoints.compact) {
      return NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _onTap(context, i),
        labelType: NavigationRailLabelType.all,
        leading: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Icon(Icons.menu_book, size: 28),
        ),
        destinations: expandedDestinations,
      );
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) => _onTap(context, i),
      animationDuration: const Duration(milliseconds: 300),
      destinations: compactDestinations,
    );
  }
}

/// macOS-style sidebar navigation
class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({super.key});

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
    final location = GoRouterState.of(context).uri.path;
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
                  final isSelected = location == item.route;
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
                    onTap: () => context.go(item.route),
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
  const MobileShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AdaptiveNavigation(),
    );
  }
}

class TabletShell extends StatelessWidget {
  const TabletShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const AdaptiveNavigation(),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const AdaptiveNavigation(),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// macOS-style shell with sidebar
class MacOSShell extends ConsumerWidget {
  const MacOSShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Book? selectedBook = ref.watch(selectedBookForPanelProvider);

    return Scaffold(
      body: BookDropZone(
        onBooksDropped: (paths) => _handleDrop(context, paths),
        child: Row(
          children: [
            const SidebarNavigation(),
            const VerticalDivider(width: 1),
            Expanded(child: child),
            if (selectedBook != null) ...[
              const VerticalDivider(width: 1),
              const MacOSRightPanel(),
            ],
          ],
        ),
      ),
    );
  }

  void _handleDrop(BuildContext context, List<String> paths) {
    final epubPaths = paths.where((p) => p.endsWith('.epub')).toList();
    if (epubPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поддерживаются только .epub файлы')),
      );
      return;
    }
    unawaited(context.push('/library', extra: epubPaths));
  }
}

class ShellWithNav extends ConsumerWidget {
  const ShellWithNav({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final capabilities = ref.watch(platformCapabilitiesProvider);

    if (capabilities.hasNativeMenuBar) {
      return MacOSShell(child: child);
    }

    if (width < AppBreakpoints.compact) {
      return MobileShell(child: child);
    } else if (width < AppBreakpoints.medium) {
      return TabletShell(child: child);
    } else {
      return DesktopShell(child: child);
    }
  }
}

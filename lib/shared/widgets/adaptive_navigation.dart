import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/adaptive_context.dart';
import '../../core/platform/app_platform.dart';
import '../../features/library/data/book_import_service.dart';
import '../../features/reader/data/parsers/format_detector.dart';
import '../../l10n/generated/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final compactDestinations = [
      NavigationDestination(icon: const Icon(Icons.library_books), label: l10n.libraryTitle),
      NavigationDestination(icon: const Icon(Icons.search), label: l10n.searchTitle),
      NavigationDestination(icon: const Icon(Icons.explore), label: l10n.catalogTitle),
      NavigationDestination(icon: const Icon(Icons.download), label: l10n.downloadsTitle),
      NavigationDestination(icon: const Icon(Icons.settings), label: l10n.settingsTitle),
    ];

    final expandedDestinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.library_books),
        label: Text(l10n.libraryTitle),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.search),
        label: Text(l10n.searchTitle),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.explore),
        label: Text(l10n.catalogTitle),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.download),
        label: Text(l10n.downloadsTitle),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings),
        label: Text(l10n.settingsTitle),
      ),
    ];

    if (context.isCompact) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        animationDuration: const Duration(milliseconds: 300),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: compactDestinations,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactRail = constraints.maxHeight < 400;
        final rail = NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          extended: context.isExpanded,
          labelType: context.isExpanded || useCompactRail
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          leading: useCompactRail
              ? null
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Icon(Icons.menu_book, size: 28),
                ),
          destinations: expandedDestinations,
        );

        // A wide foldable in landscape can select the rail while providing
        // less vertical space than its five destinations and heading require.
        return rail;
      },
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

  /// Maps list item index to shell branch index.
  /// Items not in this map are push-routes (no shell branch).
  static const _branchIndexForItem = <int, int>{
    0: 2, // Catalog → branch 2
    1: 1, // Search → branch 1
    2: 0, // Library (Все книги) → branch 0
    // 3-6: push-routes (no branch)
    7: 3, // Downloads → branch 3
    9: 4, // Settings → branch 4
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final items = [
      // Section: Обзор
      _SidebarItem(icon: Icons.explore, label: l10n.catalogTitle, route: '/catalog'),
      _SidebarItem(icon: Icons.search, label: l10n.searchTitle, route: '/search'),
      // Section: Библиотека
      _SidebarItem(icon: Icons.library_books, label: l10n.libraryTitle, route: '/library'),
      const _SidebarItem(icon: Icons.auto_stories, label: 'Чтение', route: '/collections'),
      const _SidebarItem(
        icon: Icons.bookmark_border,
        label: 'Хочу прочитать',
        route: '/collections',
      ),
      _SidebarItem(
        icon: Icons.collections_bookmark,
        label: l10n.collectionsTitle,
        route: '/collections',
      ),
      const _SidebarItem(
        icon: Icons.bookmark,
        label: 'Закладки',
        route: '/bookmarks',
      ),
      _SidebarItem(
        icon: Icons.sticky_note_2_outlined,
        label: l10n.annotationsTitle,
        route: '/annotations',
      ),
      _SidebarItem(icon: Icons.download, label: l10n.downloadsTitle, route: '/downloads'),
      // Spacer placeholder for bottom alignment
      const _SidebarItem(icon: Icons.settings, label: '', isSpacer: true),
      // Settings (bottom)
      _SidebarItem(icon: Icons.settings, label: l10n.settingsTitle, route: '/settings'),
    ];

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
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  // Spacer placeholder
                  if (item.isSpacer) {
                    return const SizedBox(height: 16);
                  }

                  // Section headers
                  if (index == 0) {
                    return const _SectionHeader('Обзор');
                  }
                  if (index == 2) {
                    return const _SectionHeader('Библиотека');
                  }

                  final branchIdx = _branchIndexForItem[index];
                  final isBranchItem = branchIdx != null;
                  final isSelected = isBranchItem && branchIdx == selectedIndex;
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
                    onTap: () {
                      if (isBranchItem) {
                        onDestinationSelected?.call(branchIdx);
                      } else {
                        final route = item.route;
                        if (route.isNotEmpty) {
                          unawaited(context.push<void>(route));
                        }
                      }
                    },
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
    this.route = '',
    this.isSpacer = false,
  });
  final IconData icon;
  final String label;
  final String route;
  final bool isSpacer;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
            FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _handleSidebarKey,
                child: AdaptiveNavigation(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: navigationShell,
              ),
            ),
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
            FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _handleSidebarKey,
                child: AdaptiveNavigation(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: navigationShell,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

KeyEventResult _handleSidebarKey(FocusNode node, KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  // Left arrow: sidebar is flat (no sub-items) — ignore.
  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    return KeyEventResult.ignored;
  }
  // Right arrow: move focus to the content FocusTraversalGroup (next scope).
  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
    FocusScope.of(node.context!).nextFocus();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
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
            FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _handleSidebarKey,
                child: SidebarNavigation(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Row(
                  children: [
                    Expanded(child: navigationShell),
                    if (selectedBook != null) ...[
                      const VerticalDivider(width: 1),
                      const MacOSRightPanel(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDrop(BuildContext context, WidgetRef ref, List<String> paths) {
    final bookPaths = paths
        .where((p) => importableExtensions.any((ext) => p.toLowerCase().endsWith('.$ext')))
        .toList();
    if (bookPaths.isEmpty) {
      unawaited(
        SmartDialog.showToast('Поддерживаются EPUB, FB2, ZIP, TXT, RTF, MOBI/AZW/PRC и DJVU'),
      );
      return;
    }
    final importService = ref.read(bookImportServiceProvider);
    for (final path in bookPaths) {
      unawaited(
        importService.importFile(path).then((result) {
          if (!context.mounted) return;
          final msg = result.isSuccess
              ? 'Импортировано: ${result.title}'
              : result.isDuplicate
              ? 'Дубликат: ${result.title}'
              : 'Ошибка: ${result.error}';
          unawaited(SmartDialog.showToast(msg));
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
    final shell = navigationShell;

    if (hasNativeMenuBar) {
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

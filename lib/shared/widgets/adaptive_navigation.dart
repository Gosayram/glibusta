import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_breakpoints.dart';

final showNavigationRailProvider = Provider<bool>((ref) => false);

class AdaptiveNavigation extends ConsumerWidget {
  const AdaptiveNavigation({super.key});

  static const List<NavigationDestination> destinations = [
    NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
    NavigationDestination(icon: Icon(Icons.explore), label: 'Каталог'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Поиск'),
    NavigationDestination(icon: Icon(Icons.library_books), label: 'Библиотека'),
    NavigationDestination(icon: Icon(Icons.download), label: 'Загрузки'),
    NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
  ];

  static const List<String> routes = [
    '/',
    '/catalog',
    '/search',
    '/library',
    '/downloads',
    '/settings',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRail = ref.watch(showNavigationRailProvider);
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = routes.indexOf(location);

    if (showRail) {
      return NavigationRail(
        selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
        onDestinationSelected: (int index) => context.go(routes[index]),
        labelType: NavigationRailLabelType.all,
        leading: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Icon(Icons.menu_book, size: 28),
        ),
        destinations: destinations
            .map(
              (NavigationDestination d) => NavigationRailDestination(
                icon: d.icon,
                label: Text(d.label),
              ),
            )
            .toList(),
      );
    }

    return NavigationBar(
      selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
      onDestinationSelected: (int index) => context.go(routes[index]),
      animationDuration: const Duration(milliseconds: 300),
      destinations: destinations,
    );
  }
}

class MobileShell extends ConsumerWidget {
  final Widget child;

  const MobileShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AdaptiveNavigation(),
    );
  }
}

class TabletShell extends ConsumerWidget {
  final Widget child;

  const TabletShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class DesktopShell extends ConsumerWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          const AdaptiveNavigation(),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: child,
          ),
        ],
      ),
    );
  }
}

class ShellWithNav extends StatelessWidget {
  final Widget child;

  const ShellWithNav({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < AppBreakpoints.compact) {
      return MobileShell(child: child);
    } else if (width < AppBreakpoints.expanded) {
      return TabletShell(child: child);
    } else {
      return DesktopShell(child: child);
    }
  }
}

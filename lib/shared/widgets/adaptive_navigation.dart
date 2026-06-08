import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final showNavigationRailProvider = Provider<bool>((ref) => false);

class AdaptiveNavigation extends ConsumerWidget {
  const AdaptiveNavigation({super.key});

  static const List<NavigationDestination> destinations = [
    NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Поиск'),
    NavigationDestination(icon: Icon(Icons.library_books), label: 'Библиотека'),
    NavigationDestination(icon: Icon(Icons.download), label: 'Загрузки'),
    NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
  ];

  static const List<String> routes = [
    '/',
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
            .map((NavigationDestination d) => NavigationRailDestination(
                  icon: d.icon,
                  label: Text(d.label),
                ))
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

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNav({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final showRail = MediaQuery.sizeOf(context).width > 600;

    if (showRail) {
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

    return Scaffold(
      body: child,
      bottomNavigationBar: const AdaptiveNavigation(),
    );
  }
}

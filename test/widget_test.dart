import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/utils/app_breakpoints.dart';
import 'package:glibusta/core/utils/platform_detector.dart';
import 'package:glibusta/shared/widgets/adaptive_navigation.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  void setScreenSize(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrapWithRouter({
    required Widget child,
    String location = '/',
    bool useShellNav = false,
  }) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (_, _, shellChild) => useShellNav ? ShellWithNav(child: shellChild) : shellChild,
          routes: [
            GoRoute(path: '/', builder: (_, _) => child),
            GoRoute(
              path: '/catalog',
              builder: (_, _) => const Scaffold(body: Text('Catalog')),
            ),
            GoRoute(
              path: '/search',
              builder: (_, _) => const Scaffold(body: Text('Search')),
            ),
            GoRoute(
              path: '/library',
              builder: (_, _) => const Scaffold(body: Text('Library')),
            ),
            GoRoute(
              path: '/downloads',
              builder: (_, _) => const Scaffold(body: Text('Downloads')),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const Scaffold(body: Text('Settings')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    return MaterialApp.router(routerConfig: router);
  }

  group('AdaptiveNavigation', () {
    testWidgets('shows NavigationBar for width < compact (400px)', (tester) async {
      setScreenSize(tester, 400, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            bottomNavigationBar: AdaptiveNavigation(),
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('shows NavigationRail for width >= compact (800px)', (tester) async {
      setScreenSize(tester, 800, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(),
                VerticalDivider(width: 1),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('shows NavigationRail for expanded width (1200px)', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(),
                VerticalDivider(width: 1),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('renders all 6 navigation labels', (tester) async {
      setScreenSize(tester, 400, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            bottomNavigationBar: AdaptiveNavigation(),
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Каталог'), findsOneWidget);
      expect(find.text('Поиск'), findsOneWidget);
      expect(find.text('Библиотека'), findsOneWidget);
      expect(find.text('Загрузки'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('tapping destination navigates to route', (tester) async {
      setScreenSize(tester, 400, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            bottomNavigationBar: AdaptiveNavigation(),
            body: Center(child: Text('Home')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsOneWidget);
    });
  });

  group('AppBreakpoints', () {
    test('compact is 600', () {
      expect(AppBreakpoints.compact, 600);
    });

    test('medium is 840', () {
      expect(AppBreakpoints.medium, 840);
    });

    test('expanded is 1200', () {
      expect(AppBreakpoints.expanded, 1200);
    });

    test('desktop is 1024', () {
      expect(AppBreakpoints.desktop, 1024);
    });
  });

  group('PlatformDetector', () {
    test('isMacOS returns false in test environment (android default)', () {
      expect(PlatformDetector.isMacOS, isFalse);
    });

    test('isDesktop returns false in test environment', () {
      expect(PlatformDetector.isDesktop, isFalse);
    });
  });

  group('ShellWithNav', () {
    testWidgets('uses MobileShell for width < 600', (tester) async {
      setScreenSize(tester, 500, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          useShellNav: true,
          child: const Scaffold(body: Text('Child')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileShell), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('uses TabletShell for width 600-839', (tester) async {
      setScreenSize(tester, 700, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          useShellNav: true,
          child: const Scaffold(body: Text('Child')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TabletShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('uses DesktopShell for width >= 840', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          useShellNav: true,
          child: const Scaffold(body: Text('Child')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('renders child content', (tester) async {
      setScreenSize(tester, 500, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          useShellNav: true,
          child: const Scaffold(body: Center(child: Text('Child'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Child'), findsOneWidget);
    });
  });

  group('MobileShell', () {
    testWidgets('renders child and bottom navigation', (tester) async {
      setScreenSize(tester, 400, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const MobileShell(
            child: Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('TabletShell', () {
    testWidgets('renders child and side rail', (tester) async {
      setScreenSize(tester, 800, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const TabletShell(
            child: Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('DesktopShell', () {
    testWidgets('renders child and side rail', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const DesktopShell(
            child: Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('SidebarNavigation', () {
    testWidgets('renders all sidebar items', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            body: Row(
              children: [
                SidebarNavigation(),
                VerticalDivider(width: 1),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Библиотека'), findsOneWidget);
      expect(find.text('Поиск'), findsOneWidget);
      expect(find.text('Загрузки'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('shows Glibusta title', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            body: Row(
              children: [
                SidebarNavigation(),
                VerticalDivider(width: 1),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Glibusta'), findsOneWidget);
    });

    testWidgets('highlights selected route', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        wrapWithRouter(
          child: const Scaffold(
            body: Row(
              children: [
                SidebarNavigation(),
                VerticalDivider(width: 1),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final homeTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Библиотека'),
      );
      expect(homeTile.selected, isTrue);

      final searchTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Поиск'),
      );
      expect(searchTile.selected, isFalse);
    });
  });
}

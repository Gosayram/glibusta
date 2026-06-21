import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/utils/app_breakpoints.dart';
import 'package:glibusta/core/utils/platform_detector.dart';
import 'package:glibusta/l10n/generated/app_localizations.dart';
import 'package:glibusta/shared/widgets/adaptive_navigation.dart';

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  void setScreenSize(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('AdaptiveNavigation', () {
    testWidgets('renders NavigationBar on compact width', (tester) async {
      setScreenSize(tester, 400, 600);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AdaptiveNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('renders NavigationRail on medium+ width', (tester) async {
      setScreenSize(tester, 800, 600);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AdaptiveNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('renders all 4 navigation labels', (tester) async {
      setScreenSize(tester, 400, 600);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AdaptiveNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('calls onDestinationSelected on tap', (tester) async {
      setScreenSize(tester, 400, 600);
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AdaptiveNavigation(
              selectedIndex: 0,
              onDestinationSelected: (i) => tappedIndex = i,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(tappedIndex, 1);
    });
  });

  group('SidebarNavigation', () {
    testWidgets('renders all sidebar items', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SidebarNavigation(
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Collections'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows Glibusta title', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SidebarNavigation(
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Glibusta'), findsOneWidget);
    });

    testWidgets('highlights selected item', (tester) async {
      setScreenSize(tester, 1200, 600);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SidebarNavigation(
              selectedIndex: 1,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final homeTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Library'),
      );
      expect(homeTile.selected, isFalse);

      final searchTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Search'),
      );
      expect(searchTile.selected, isTrue);
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
}

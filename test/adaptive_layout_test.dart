import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/widgets/adaptive_navigation.dart';
import 'package:glibusta/shared/widgets/book_grid.dart';
import 'package:glibusta/shared/widgets/library_master_detail.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  void setScreenSize(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  List<Book> makeBooks(int count) {
    return List.generate(
      count,
      (i) => Book(
        id: 'book_$i',
        title: 'Book $i',
        authorIds: ['Author $i'],
        genreIds: const [],
        description: null,
        coverUrl: null,
        publishDate: null,
        availableFormats: const [],
        source: const BookSourceInfo(sourceId: '', sourceUrl: ''),
      ),
    );
  }

  Widget buildTestApp(Widget child, {String location = '/'}) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/library',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/reader/:id',
          builder: (_, _) => const Scaffold(body: Text('Reader')),
        ),
        GoRoute(
          path: '/book/:id',
          builder: (_, _) => const Scaffold(body: Text('Details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // ─── Small Android (360x640) ──────────────────────────
  group('Small Android 360x640', () {
    testWidgets('shows NavigationBar (phone)', (tester) async {
      setScreenSize(tester, 360, 640);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Column(
              children: [
                const Expanded(child: Center(child: Text('Content'))),
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('BookGrid shows 2 cards per row', (tester) async {
      setScreenSize(tester, 360, 640);
      final books = makeBooks(6);

      await tester.pumpWidget(
        buildTestApp(BookGrid(books: books)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, 140);
    });
  });

  // ─── Large Android (412x915) ──────────────────────────
  group('Large Android 412x915', () {
    testWidgets('shows NavigationBar (phone)', (tester) async {
      setScreenSize(tester, 412, 915);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Column(
              children: [
                const Expanded(child: Center(child: Text('Content'))),
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('BookGrid renders with maxCrossAxisExtent 140', (tester) async {
      setScreenSize(tester, 412, 915);
      final books = makeBooks(8);

      await tester.pumpWidget(
        buildTestApp(BookGrid(books: books)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, 140);
    });
  });

  // ─── Tablet (800x1280) ────────────────────────────────
  group('Tablet 800x1280', () {
    testWidgets('shows NavigationRail', (tester) async {
      setScreenSize(tester, 800, 1280);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('LibraryMasterDetail renders with list + detail', (tester) async {
      setScreenSize(tester, 800, 1280);
      final books = makeBooks(4);

      await tester.pumpWidget(
        buildTestApp(LibraryMasterDetail(books: books)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsWidgets);
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('LibraryMasterDetail shows empty state initially', (tester) async {
      setScreenSize(tester, 800, 1280);
      final books = makeBooks(3);

      await tester.pumpWidget(
        buildTestApp(LibraryMasterDetail(books: books)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Выберите книгу'), findsOneWidget);
    });

    testWidgets('LibraryMasterDetail selects book on tap', (tester) async {
      setScreenSize(tester, 800, 1280);
      final books = makeBooks(3);

      final router = GoRouter(
        initialLocation: '/library',
        routes: [
          GoRoute(
            path: '/library',
            builder: (_, _) => Scaffold(body: LibraryMasterDetail(books: books)),
          ),
          GoRoute(
            path: '/reader/:id',
            builder: (_, _) => const Scaffold(body: Text('Reader')),
          ),
          GoRoute(
            path: '/book/:id',
            builder: (_, _) => const Scaffold(body: Text('Details')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book 0'));
      await tester.pumpAndSettle();

      expect(find.text('Author 0'), findsWidgets);
      expect(find.text('Читать'), findsOneWidget);
      expect(find.text('Подробнее'), findsOneWidget);
    });
  });

  // ─── Foldable Landscape (594x360 → 722x360) ──────────
  group('Foldable Landscape', () {
    testWidgets('shows NavigationRail for 722x360', (tester) async {
      setScreenSize(tester, 722, 360);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  // ─── macOS 900x620 (minimum window) ───────────────────
  group('macOS 900x620 (minimum window)', () {
    testWidgets('shows NavigationRail for desktop width', (tester) async {
      setScreenSize(tester, 900, 620);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('shows 4 rail labels', (tester) async {
      setScreenSize(tester, 900, 620);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: SizedBox.shrink()),
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
  });

  // ─── macOS 1200x800 (default window) ──────────────────
  group('macOS 1200x800 (default window)', () {
    testWidgets('shows NavigationRail', (tester) async {
      setScreenSize(tester, 1200, 800);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('LibraryMasterDetail at 1200 width', (tester) async {
      setScreenSize(tester, 1200, 800);
      final books = makeBooks(5);

      await tester.pumpWidget(
        buildTestApp(LibraryMasterDetail(books: books)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book 0'), findsOneWidget);
      expect(find.text('Выберите книгу'), findsOneWidget);
    });
  });

  // ─── macOS Fullscreen (1920x1080) ─────────────────────
  group('macOS Fullscreen 1920x1080', () {
    testWidgets('shows NavigationRail', (tester) async {
      setScreenSize(tester, 1920, 1080);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Row(
              children: [
                AdaptiveNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('BookGrid renders with correct delegate', (tester) async {
      setScreenSize(tester, 1920, 1080);
      final books = makeBooks(12);

      await tester.pumpWidget(
        buildTestApp(BookGrid(books: books)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, 260);
    });
  });

  // ─── AdaptiveNavigation widget tests ──────────────────
  group('AdaptiveNavigation', () {
    testWidgets('renders NavigationBar on compact', (tester) async {
      setScreenSize(tester, 360, 640);
      await tester.pumpWidget(
        buildTestApp(
          AdaptiveNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('renders NavigationRail on medium+', (tester) async {
      setScreenSize(tester, 800, 1280);
      await tester.pumpWidget(
        buildTestApp(
          AdaptiveNavigation(
            selectedIndex: 1,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/book_details/presentation/book_details_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/reader/presentation/reader_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/adaptive_navigation.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return ScaffoldWithNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/catalog',
            name: 'catalog',
            builder: (BuildContext context, GoRouterState state) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (BuildContext context, GoRouterState state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (BuildContext context, GoRouterState state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/downloads',
            name: 'downloads',
            builder: (BuildContext context, GoRouterState state) => const DownloadsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/book/:bookId',
        name: 'bookDetails',
        builder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return BookDetailsScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        builder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return ReaderScreen(bookId: bookId);
        },
      ),
    ],
  ),
);

class GlibustaApp extends ConsumerStatefulWidget {
  const GlibustaApp({super.key});

  @override
  ConsumerState<GlibustaApp> createState() => _GlibustaAppState();
}

class _GlibustaAppState extends ConsumerState<GlibustaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _saveState();
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _saveState() {
    // Persist reading progress, download states, etc.
    // Handled by Drift auto-persistence in repositories
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Glibusta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      restorationScopeId: 'app',
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glibusta'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Glibusta',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Кросс-платформенная библиотека',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search),
              label: const Text('Найти книгу'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    restorationScopeId: 'router',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/library',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
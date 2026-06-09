import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/book_details/presentation/book_details_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/reader/presentation/reader_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/diagnostics_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/adaptive_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return ShellWithNav(child: child);
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
          GoRoute(
            path: '/settings/diagnostics',
            name: 'diagnostics',
            builder: (BuildContext context, GoRouterState state) => const DiagnosticsScreen(),
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
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/book_details/presentation/book_details_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/reader/presentation/reader_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/diagnostics_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/adaptive_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    onException: (context, state, router) {
      debugPrint('Router exception at ${state.uri.path}: ${state.error}');
      if (state.uri.path != '/error') {
        final message = state.error?.toString() ?? 'Unknown router error';
        router.go('/error?message=${Uri.encodeComponent(message)}');
      }
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return ShellWithNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            redirect: (_, state) {
              if (state.uri.path == '/') return '/library';
              return null;
            },
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (BuildContext context, GoRouterState state) => const LibraryScreen(),
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
            path: '/downloads',
            name: 'downloads',
            builder: (BuildContext context, GoRouterState state) => const DownloadsScreen(),
          ),
          GoRoute(
            path: '/collections',
            name: 'collections',
            builder: (BuildContext context, GoRouterState state) => const CollectionsScreen(),
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
          GoRoute(
            path: '/404',
            redirect: (_, state) => '/error',
          ),
          GoRoute(
            path: '/error',
            name: 'error',
            builder: (BuildContext context, GoRouterState state) => _ErrorRoute(
              message: state.uri.queryParameters['message'],
            ),
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

class _ErrorRoute extends StatelessWidget {
  final String? message;

  const _ErrorRoute({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ошибка')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Страница не найдена или произошла ошибка навигации',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/library'),
                    child: const Text('В библиотеку'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

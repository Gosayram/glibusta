import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/annotations/presentation/annotations_screen.dart';
import '../features/book_details/presentation/book_details_screen.dart';
import '../features/bookmarks/presentation/bookmarks_screen.dart';
import '../features/catalog/presentation/author_detail_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/catalog/presentation/genre_books_screen.dart';
import '../features/catalog/presentation/genre_list_screen.dart';
import '../features/catalog/presentation/recent_books_screen.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/quotes/presentation/quotes_screen.dart';
import '../features/reader/presentation/chapter_split_rules_screen.dart';
import '../features/reader/presentation/reader_entry_screen.dart';
import '../features/reader/presentation/reading_info_settings_screen.dart';
import '../features/reading_stats/presentation/reading_stats_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/series/presentation/series_detail_screen.dart';
import '../features/series/presentation/series_screen.dart';
import '../features/settings/presentation/diagnostics_screen.dart';
import '../features/settings/presentation/font_download_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/storage_management_screen.dart';
import '../features/settings/presentation/tag_management_screen.dart';
import '../shared/widgets/adaptive_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/library',
    onException: (context, state, router) {
      if (kDebugMode) {
        debugPrint('Router exception at ${state.uri.path}: ${state.error}');
      }
      if (state.uri.path != '/error') {
        final message = state.error?.toString() ?? 'Unknown router error';
        router.go('/error?message=${Uri.encodeComponent(message)}');
      }
    },
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder:
            (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
              return ShellWithNav(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          // ── Library ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                name: 'library',
                builder: (BuildContext context, GoRouterState state) => const LibraryScreen(),
              ),
            ],
          ),
          // ── Search ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (BuildContext context, GoRouterState state) {
                  final category = state.uri.queryParameters['category'];
                  return SearchScreen(initialCategory: category);
                },
              ),
            ],
          ),
          // ── Downloads ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/downloads',
                name: 'downloads',
                builder: (BuildContext context, GoRouterState state) => const DownloadsScreen(),
              ),
            ],
          ),
          // ── Settings ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Redirect from root to library
      GoRoute(
        path: '/',
        name: 'home',
        redirect: (_, state) {
          if (state.uri.path == '/') return '/library';
          return null;
        },
      ),
      // Catalog (not a main tab, but within shell for nav)
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return child;
        },
        routes: [
          GoRoute(
            path: '/catalog',
            name: 'catalog',
            builder: (BuildContext context, GoRouterState state) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/collections',
            name: 'collections',
            builder: (BuildContext context, GoRouterState state) => const CollectionsScreen(),
          ),
          GoRoute(
            path: '/annotations',
            name: 'annotations',
            builder: (BuildContext context, GoRouterState state) => const AnnotationsScreen(),
          ),
          GoRoute(
            path: '/stats',
            name: 'stats',
            builder: (BuildContext context, GoRouterState state) => const ReadingStatsScreen(),
          ),
          GoRoute(
            path: '/series',
            name: 'series',
            builder: (BuildContext context, GoRouterState state) => const SeriesScreen(),
          ),
          GoRoute(
            path: '/settings/diagnostics',
            name: 'diagnostics',
            builder: (BuildContext context, GoRouterState state) => const DiagnosticsScreen(),
          ),
          GoRoute(
            path: '/settings/fonts',
            name: 'fonts',
            builder: (BuildContext context, GoRouterState state) => const FontDownloadScreen(),
          ),
          GoRoute(
            path: '/settings/storage',
            name: 'storage',
            builder: (BuildContext context, GoRouterState state) => const StorageManagementScreen(),
          ),
          GoRoute(
            path: '/settings/tags',
            name: 'tags',
            builder: (BuildContext context, GoRouterState state) => const TagManagementScreen(),
          ),
          GoRoute(
            path: '/settings/reading-info',
            name: 'reading-info',
            builder: (BuildContext context, GoRouterState state) =>
                const ReadingInfoSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/chapter-split-rules',
            name: 'chapter-split-rules',
            builder: (BuildContext context, GoRouterState state) => const ChapterSplitRulesScreen(),
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
      // Detail routes outside shell (full-screen)
      GoRoute(
        path: '/book/:bookId',
        name: 'bookDetails',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: BookDetailsScreen(bookId: bookId),
            transitionsBuilder: (_, animation, second, child) {
              final offset = Tween(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: ReaderEntryScreen(bookId: bookId),
            transitionsBuilder: (_, animation, second, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/series/:seriesId',
        name: 'seriesDetail',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final seriesId = state.pathParameters['seriesId']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: SeriesDetailScreen(seriesId: seriesId),
            transitionsBuilder: (_, animation, second, child) {
              final offset = Tween(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/quotes/:bookId',
        name: 'quotes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return QuotesScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/annotations/book/:bookId',
        name: 'bookAnnotations',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return AnnotationsScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/author/:authorId',
        name: 'authorDetail',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final authorId = state.pathParameters['authorId']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: AuthorDetailScreen(authorId: authorId),
            transitionsBuilder: (_, animation, second, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/genres',
        name: 'genreList',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const GenreListScreen(),
            transitionsBuilder: (_, animation, second, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/genre/:genreId',
        name: 'genreBooks',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final genreId = state.pathParameters['genreId']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: GenreBooksScreen(genreId: genreId),
            transitionsBuilder: (_, animation, second, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/recent',
        name: 'recentBooks',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const RecentBooksScreen(),
            transitionsBuilder: (_, animation, second, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/bookmarks/:bookId',
        name: 'bookmarks',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return BookmarksScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/notes/:bookId',
        name: 'notes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final bookId = state.pathParameters['bookId']!;
          return NotesScreen(bookId: bookId);
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

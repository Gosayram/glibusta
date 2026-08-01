import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/annotations/presentation/annotations_screen.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/highlights/presentation/highlights_notes_screen.dart';
import '../features/reading_stats/presentation/reading_stats_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<CollectionsRoute>(path: '/collections', name: 'collections')
class CollectionsRoute extends GoRouteData with $CollectionsRoute {
  const CollectionsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CollectionsScreen();
  }
}

@TypedGoRoute<CollectionDetailRoute>(path: '/collections/:collectionId', name: 'collectionDetail')
class CollectionDetailRoute extends GoRouteData with $CollectionDetailRoute {
  const CollectionDetailRoute({required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return CollectionDetailScreen(collectionId: collectionId);
  }
}

@TypedGoRoute<AnnotationsRoute>(path: '/annotations', name: 'annotations')
class AnnotationsRoute extends GoRouteData with $AnnotationsRoute {
  const AnnotationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const AnnotationsScreen();
  }
}

@TypedGoRoute<StatsRoute>(path: '/stats', name: 'stats')
class StatsRoute extends GoRouteData with $StatsRoute {
  const StatsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ReadingStatsScreen();
  }
}

@TypedGoRoute<HighlightsRoute>(path: '/highlights/:bookId', name: 'highlights')
class HighlightsRoute extends GoRouteData with $HighlightsRoute {
  const HighlightsRoute({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return HighlightsNotesScreen(bookId: bookId);
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/annotations/presentation/annotations_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/reading_stats/presentation/reading_stats_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<CatalogRoute>(path: '/catalog', name: 'catalog')
class CatalogRoute extends GoRouteData with $CatalogRoute {
  const CatalogRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CatalogScreen();
  }
}

@TypedGoRoute<CollectionsRoute>(path: '/collections', name: 'collections')
class CollectionsRoute extends GoRouteData with $CollectionsRoute {
  const CollectionsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CollectionsScreen();
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

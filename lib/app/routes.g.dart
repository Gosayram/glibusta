// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $catalogRoute,
  $collectionsRoute,
  $annotationsRoute,
  $statsRoute,
];

RouteBase get $catalogRoute => GoRouteData.$route(
  path: '/catalog',
  name: 'catalog',
  factory: $CatalogRoute._fromState,
);

mixin $CatalogRoute on GoRouteData {
  static CatalogRoute _fromState(GoRouterState state) => const CatalogRoute();

  @override
  String get location => GoRouteData.$location('/catalog');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $collectionsRoute => GoRouteData.$route(
  path: '/collections',
  name: 'collections',
  factory: $CollectionsRoute._fromState,
);

mixin $CollectionsRoute on GoRouteData {
  static CollectionsRoute _fromState(GoRouterState state) => const CollectionsRoute();

  @override
  String get location => GoRouteData.$location('/collections');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $annotationsRoute => GoRouteData.$route(
  path: '/annotations',
  name: 'annotations',
  factory: $AnnotationsRoute._fromState,
);

mixin $AnnotationsRoute on GoRouteData {
  static AnnotationsRoute _fromState(GoRouterState state) => const AnnotationsRoute();

  @override
  String get location => GoRouteData.$location('/annotations');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $statsRoute => GoRouteData.$route(
  path: '/stats',
  name: 'stats',
  factory: $StatsRoute._fromState,
);

mixin $StatsRoute on GoRouteData {
  static StatsRoute _fromState(GoRouterState state) => const StatsRoute();

  @override
  String get location => GoRouteData.$location('/stats');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $collectionsRoute,
  $collectionDetailRoute,
  $annotationsRoute,
  $allBookmarksRoute,
  $statsRoute,
  $highlightsRoute,
];

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

RouteBase get $collectionDetailRoute => GoRouteData.$route(
  path: '/collections/:collectionId',
  name: 'collectionDetail',
  factory: $CollectionDetailRoute._fromState,
);

mixin $CollectionDetailRoute on GoRouteData {
  static CollectionDetailRoute _fromState(GoRouterState state) => CollectionDetailRoute(
    collectionId: state.pathParameters['collectionId']!,
  );

  CollectionDetailRoute get _self => this as CollectionDetailRoute;

  @override
  String get location => GoRouteData.$location(
    '/collections/${Uri.encodeComponent(_self.collectionId)}',
  );

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

RouteBase get $allBookmarksRoute => GoRouteData.$route(
  path: '/bookmarks',
  name: 'allBookmarks',
  factory: $AllBookmarksRoute._fromState,
);

mixin $AllBookmarksRoute on GoRouteData {
  static AllBookmarksRoute _fromState(GoRouterState state) => const AllBookmarksRoute();

  @override
  String get location => GoRouteData.$location('/bookmarks');

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

RouteBase get $highlightsRoute => GoRouteData.$route(
  path: '/highlights/:bookId',
  name: 'highlights',
  factory: $HighlightsRoute._fromState,
);

mixin $HighlightsRoute on GoRouteData {
  static HighlightsRoute _fromState(GoRouterState state) =>
      HighlightsRoute(bookId: state.pathParameters['bookId']!);

  HighlightsRoute get _self => this as HighlightsRoute;

  @override
  String get location => GoRouteData.$location('/highlights/${Uri.encodeComponent(_self.bookId)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categories)
final categoriesProvider = CategoriesProvider._();

final class CategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SearchGenreItem>>,
          List<SearchGenreItem>,
          FutureOr<List<SearchGenreItem>>
        >
    with $FutureModifier<List<SearchGenreItem>>, $FutureProvider<List<SearchGenreItem>> {
  CategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<SearchGenreItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SearchGenreItem>> create(Ref ref) {
    return categories(ref);
  }
}

String _$categoriesHash() => r'6592cdd0cc9d4f06121cc9164b2aecbc9d7d112a';

@ProviderFor(popularBooks)
final popularBooksProvider = PopularBooksProvider._();

final class PopularBooksProvider
    extends $FunctionalProvider<AsyncValue<List<Book>>, List<Book>, FutureOr<List<Book>>>
    with $FutureModifier<List<Book>>, $FutureProvider<List<Book>> {
  PopularBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularBooksHash();

  @$internal
  @override
  $FutureProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Book>> create(Ref ref) {
    return popularBooks(ref);
  }
}

String _$popularBooksHash() => r'84b80e31b2dbdcddad37af65884c5032b1e93c9f';

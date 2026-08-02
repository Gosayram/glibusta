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

String _$categoriesHash() => r'd53efa2f220be02e355180bf6b35052d7f0b05c0';

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

String _$popularBooksHash() => r'54b11958819f81227f363fa036c8b43285053eae';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genre_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(genreList)
final genreListProvider = GenreListProvider._();

final class GenreListProvider
    extends
        $FunctionalProvider<
          AsyncValue<GenreListResponse>,
          GenreListResponse,
          FutureOr<GenreListResponse>
        >
    with
        $FutureModifier<GenreListResponse>,
        $FutureProvider<GenreListResponse> {
  GenreListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'genreListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$genreListHash();

  @$internal
  @override
  $FutureProviderElement<GenreListResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GenreListResponse> create(Ref ref) {
    return genreList(ref);
  }
}

String _$genreListHash() => r'9366ff4ab62fdb467903746bffa9e124abccbc1a';

@ProviderFor(genreBooks)
final genreBooksProvider = GenreBooksFamily._();

final class GenreBooksProvider
    extends
        $FunctionalProvider<
          AsyncValue<GenreBooksResponse>,
          GenreBooksResponse,
          FutureOr<GenreBooksResponse>
        >
    with
        $FutureModifier<GenreBooksResponse>,
        $FutureProvider<GenreBooksResponse> {
  GenreBooksProvider._({
    required GenreBooksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'genreBooksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$genreBooksHash();

  @override
  String toString() {
    return r'genreBooksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GenreBooksResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GenreBooksResponse> create(Ref ref) {
    final argument = this.argument as String;
    return genreBooks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GenreBooksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$genreBooksHash() => r'3e8e9d79e05af44a67c4aa63158942a5e6e92c52';

final class GenreBooksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GenreBooksResponse>, String> {
  GenreBooksFamily._()
    : super(
        retry: null,
        name: r'genreBooksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GenreBooksProvider call(String genreId) =>
      GenreBooksProvider._(argument: genreId, from: this);

  @override
  String toString() => r'genreBooksProvider';
}

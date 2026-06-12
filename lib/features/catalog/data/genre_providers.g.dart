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

String _$genreListHash() => r'a375d1bf78c8a5a6adaface9756ab1b5faf16707';

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

String _$genreBooksHash() => r'62ed27ed57ad33464405110b173464b83a94c0a4';

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

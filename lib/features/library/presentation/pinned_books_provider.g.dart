// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pinned_books_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PinnedBooks)
final pinnedBooksProvider = PinnedBooksProvider._();

final class PinnedBooksProvider extends $AsyncNotifierProvider<PinnedBooks, List<String>> {
  PinnedBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinnedBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinnedBooksHash();

  @$internal
  @override
  PinnedBooks create() => PinnedBooks();
}

String _$pinnedBooksHash() => r'3cc0c328f9b05df153b2edd9ffa2b9deed3d1227';

abstract class _$PinnedBooks extends $AsyncNotifier<List<String>> {
  FutureOr<List<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(pinnedBooksList)
final pinnedBooksListProvider = PinnedBooksListProvider._();

final class PinnedBooksListProvider
    extends $FunctionalProvider<AsyncValue<List<Book>>, List<Book>, FutureOr<List<Book>>>
    with $FutureModifier<List<Book>>, $FutureProvider<List<Book>> {
  PinnedBooksListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinnedBooksListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinnedBooksListHash();

  @$internal
  @override
  $FutureProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Book>> create(Ref ref) {
    return pinnedBooksList(ref);
  }
}

String _$pinnedBooksListHash() => r'cdf0095de990d763b9b30b000fd7349885ed00e0';

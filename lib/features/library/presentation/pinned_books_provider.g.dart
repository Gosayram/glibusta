// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pinned_books_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PinnedBooks)
final pinnedBooksProvider = PinnedBooksProvider._();

final class PinnedBooksProvider
    extends $NotifierProvider<PinnedBooks, List<String>> {
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

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$pinnedBooksHash() => r'b997d0866bc5616fbde6ac3da3a6baebbe0ac0b5';

abstract class _$PinnedBooks extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(pinnedBooksList)
final pinnedBooksListProvider = PinnedBooksListProvider._();

final class PinnedBooksListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Book>>,
          List<Book>,
          FutureOr<List<Book>>
        >
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

String _$pinnedBooksListHash() => r'7627aa023314221941a58a9b5a7cb1fae860aaaf';

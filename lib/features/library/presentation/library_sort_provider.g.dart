// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_sort_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibrarySortConfig)
final librarySortConfigProvider = LibrarySortConfigProvider._();

final class LibrarySortConfigProvider
    extends
        $NotifierProvider<LibrarySortConfig, ({LibrarySortField field, LibrarySortOrder order})> {
  LibrarySortConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySortConfigProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySortConfigHash();

  @$internal
  @override
  LibrarySortConfig create() => LibrarySortConfig();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({LibrarySortField field, LibrarySortOrder order}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({LibrarySortField field, LibrarySortOrder order})>(
        value,
      ),
    );
  }
}

String _$librarySortConfigHash() => r'e488c0bcf80dc3a283fe7aef2c07a03e916ca0d6';

abstract class _$LibrarySortConfig
    extends $Notifier<({LibrarySortField field, LibrarySortOrder order})> {
  ({LibrarySortField field, LibrarySortOrder order}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({LibrarySortField field, LibrarySortOrder order}),
              ({LibrarySortField field, LibrarySortOrder order})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({LibrarySortField field, LibrarySortOrder order}),
                ({LibrarySortField field, LibrarySortOrder order})
              >,
              ({LibrarySortField field, LibrarySortOrder order}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(LibraryTagFilter)
final libraryTagFilterProvider = LibraryTagFilterProvider._();

final class LibraryTagFilterProvider extends $NotifierProvider<LibraryTagFilter, List<String>> {
  LibraryTagFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryTagFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryTagFilterHash();

  @$internal
  @override
  LibraryTagFilter create() => LibraryTagFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$libraryTagFilterHash() => r'38f307468718eefd0e29a91e84deb57c5f78da82';

abstract class _$LibraryTagFilter extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(filteredLibraryBooks)
final filteredLibraryBooksProvider = FilteredLibraryBooksProvider._();

final class FilteredLibraryBooksProvider
    extends $FunctionalProvider<AsyncValue<List<Book>>, List<Book>, FutureOr<List<Book>>>
    with $FutureModifier<List<Book>>, $FutureProvider<List<Book>> {
  FilteredLibraryBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredLibraryBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredLibraryBooksHash();

  @$internal
  @override
  $FutureProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Book>> create(Ref ref) {
    return filteredLibraryBooks(ref);
  }
}

String _$filteredLibraryBooksHash() => r'17efc56d26474fd06dea364ea18943a749c11e91';

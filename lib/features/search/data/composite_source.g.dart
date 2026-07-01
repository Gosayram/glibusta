// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'composite_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookSource)
final bookSourceProvider = BookSourceProvider._();

final class BookSourceProvider
    extends $FunctionalProvider<BookSource, BookSource, BookSource>
    with $Provider<BookSource> {
  BookSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceHash();

  @$internal
  @override
  $ProviderElement<BookSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookSource create(Ref ref) {
    return bookSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSource>(value),
    );
  }
}

String _$bookSourceHash() => r'd79dc6fc68c97f06faaaa377346a81b4356000e5';

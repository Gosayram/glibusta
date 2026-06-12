// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flibusta_api_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(flibustaApiSource)
final flibustaApiSourceProvider = FlibustaApiSourceProvider._();

final class FlibustaApiSourceProvider
    extends $FunctionalProvider<FlibustaApiSource, FlibustaApiSource, FlibustaApiSource>
    with $Provider<FlibustaApiSource> {
  FlibustaApiSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flibustaApiSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flibustaApiSourceHash();

  @$internal
  @override
  $ProviderElement<FlibustaApiSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlibustaApiSource create(Ref ref) {
    return flibustaApiSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlibustaApiSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlibustaApiSource>(value),
    );
  }
}

String _$flibustaApiSourceHash() => r'a02df17f151778e7bd6dd8fc746c86f02c5a23ad';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flibusta_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(flibustaSource)
final flibustaSourceProvider = FlibustaSourceProvider._();

final class FlibustaSourceProvider
    extends $FunctionalProvider<FlibustaHtmlSource, FlibustaHtmlSource, FlibustaHtmlSource>
    with $Provider<FlibustaHtmlSource> {
  FlibustaSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flibustaSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flibustaSourceHash();

  @$internal
  @override
  $ProviderElement<FlibustaHtmlSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlibustaHtmlSource create(Ref ref) {
    return flibustaSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlibustaHtmlSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlibustaHtmlSource>(value),
    );
  }
}

String _$flibustaSourceHash() => r'08c8192b43c50de281bbd9cc2d66b8f3ff52a51f';

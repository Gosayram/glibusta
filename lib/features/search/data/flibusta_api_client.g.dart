// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flibusta_api_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(flibustaApiClient)
final flibustaApiClientProvider = FlibustaApiClientProvider._();

final class FlibustaApiClientProvider
    extends $FunctionalProvider<FlibustaApiClient, FlibustaApiClient, FlibustaApiClient>
    with $Provider<FlibustaApiClient> {
  FlibustaApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flibustaApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flibustaApiClientHash();

  @$internal
  @override
  $ProviderElement<FlibustaApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlibustaApiClient create(Ref ref) {
    return flibustaApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlibustaApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlibustaApiClient>(value),
    );
  }
}

String _$flibustaApiClientHash() => r'4aa059323c0b8fb2c4e79dee41932df6ebc30b92';

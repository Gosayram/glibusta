// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lifecycle_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lifecycleService)
final lifecycleServiceProvider = LifecycleServiceProvider._();

final class LifecycleServiceProvider
    extends
        $FunctionalProvider<
          LifecycleService,
          LifecycleService,
          LifecycleService
        >
    with $Provider<LifecycleService> {
  LifecycleServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lifecycleServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lifecycleServiceHash();

  @$internal
  @override
  $ProviderElement<LifecycleService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LifecycleService create(Ref ref) {
    return lifecycleService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LifecycleService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LifecycleService>(value),
    );
  }
}

String _$lifecycleServiceHash() => r'84e47bcda991e213f50bc7ef583ac937583b6507';

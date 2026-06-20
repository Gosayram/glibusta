// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cacheSize)
final cacheSizeProvider = CacheSizeProvider._();

final class CacheSizeProvider extends $FunctionalProvider<int, int, int> with $Provider<int> {
  CacheSizeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheSizeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheSizeHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return cacheSize(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$cacheSizeHash() => r'2339986c8c38f750ba7f5ebfd230557db6791a52';

@ProviderFor(cacheSizeByType)
final cacheSizeByTypeProvider = CacheSizeByTypeProvider._();

final class CacheSizeByTypeProvider
    extends $FunctionalProvider<Map<CacheType, int>, Map<CacheType, int>, Map<CacheType, int>>
    with $Provider<Map<CacheType, int>> {
  CacheSizeByTypeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheSizeByTypeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheSizeByTypeHash();

  @$internal
  @override
  $ProviderElement<Map<CacheType, int>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<CacheType, int> create(Ref ref) {
    return cacheSizeByType(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<CacheType, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<CacheType, int>>(value),
    );
  }
}

String _$cacheSizeByTypeHash() => r'06ed8ac28bc610a516cb317069bd7da17fca7f86';

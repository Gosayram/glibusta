// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(smartCollections)
final smartCollectionsProvider = SmartCollectionsProvider._();

final class SmartCollectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SmartCollection>>,
          List<SmartCollection>,
          FutureOr<List<SmartCollection>>
        >
    with $FutureModifier<List<SmartCollection>>, $FutureProvider<List<SmartCollection>> {
  SmartCollectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartCollectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartCollectionsHash();

  @$internal
  @override
  $FutureProviderElement<List<SmartCollection>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SmartCollection>> create(Ref ref) {
    return smartCollections(ref);
  }
}

String _$smartCollectionsHash() => r'14576556b52fb0540b25fc1e9e356bc3c042ce06';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'continue_reading_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(continueReadingInfos)
final continueReadingInfosProvider = ContinueReadingInfosProvider._();

final class ContinueReadingInfosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContinueReadingInfo>>,
          List<ContinueReadingInfo>,
          FutureOr<List<ContinueReadingInfo>>
        >
    with
        $FutureModifier<List<ContinueReadingInfo>>,
        $FutureProvider<List<ContinueReadingInfo>> {
  ContinueReadingInfosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueReadingInfosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueReadingInfosHash();

  @$internal
  @override
  $FutureProviderElement<List<ContinueReadingInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContinueReadingInfo>> create(Ref ref) {
    return continueReadingInfos(ref);
  }
}

String _$continueReadingInfosHash() =>
    r'3cf00bfb36ea2be1d4062dd1707d6d0a0b43db42';

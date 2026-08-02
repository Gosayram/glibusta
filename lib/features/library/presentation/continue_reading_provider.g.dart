// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'continue_reading_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(continueReading)
final continueReadingProvider = ContinueReadingProvider._();

final class ContinueReadingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContinueReadingBook>>,
          List<ContinueReadingBook>,
          FutureOr<List<ContinueReadingBook>>
        >
    with
        $FutureModifier<List<ContinueReadingBook>>,
        $FutureProvider<List<ContinueReadingBook>> {
  ContinueReadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueReadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueReadingHash();

  @$internal
  @override
  $FutureProviderElement<List<ContinueReadingBook>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContinueReadingBook>> create(Ref ref) {
    return continueReading(ref);
  }
}

String _$continueReadingHash() => r'57faa0cd5d097dbda5b9d1304ad725bf42239e4e';

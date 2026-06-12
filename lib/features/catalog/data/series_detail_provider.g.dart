// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(seriesDetailFromServer)
final seriesDetailFromServerProvider = SeriesDetailFromServerFamily._();

final class SeriesDetailFromServerProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeriesDetailResponse>,
          SeriesDetailResponse,
          FutureOr<SeriesDetailResponse>
        >
    with
        $FutureModifier<SeriesDetailResponse>,
        $FutureProvider<SeriesDetailResponse> {
  SeriesDetailFromServerProvider._({
    required SeriesDetailFromServerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seriesDetailFromServerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seriesDetailFromServerHash();

  @override
  String toString() {
    return r'seriesDetailFromServerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SeriesDetailResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeriesDetailResponse> create(Ref ref) {
    final argument = this.argument as String;
    return seriesDetailFromServer(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesDetailFromServerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seriesDetailFromServerHash() =>
    r'a3125dc4823796106da3c7bc375dcdc0e24f0349';

final class SeriesDetailFromServerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SeriesDetailResponse>, String> {
  SeriesDetailFromServerFamily._()
    : super(
        retry: null,
        name: r'seriesDetailFromServerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeriesDetailFromServerProvider call(String seriesId) =>
      SeriesDetailFromServerProvider._(argument: seriesId, from: this);

  @override
  String toString() => r'seriesDetailFromServerProvider';
}

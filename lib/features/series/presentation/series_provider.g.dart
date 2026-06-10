// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allSeries)
final allSeriesProvider = AllSeriesProvider._();

final class AllSeriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SeriesInfo>>,
          List<SeriesInfo>,
          FutureOr<List<SeriesInfo>>
        >
    with $FutureModifier<List<SeriesInfo>>, $FutureProvider<List<SeriesInfo>> {
  AllSeriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allSeriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allSeriesHash();

  @$internal
  @override
  $FutureProviderElement<List<SeriesInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SeriesInfo>> create(Ref ref) {
    return allSeries(ref);
  }
}

String _$allSeriesHash() => r'7f23691963ac07206cdb3771dd9b573bcb094901';

@ProviderFor(seriesDetail)
final seriesDetailProvider = SeriesDetailFamily._();

final class SeriesDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeriesDetail?>,
          SeriesDetail?,
          FutureOr<SeriesDetail?>
        >
    with $FutureModifier<SeriesDetail?>, $FutureProvider<SeriesDetail?> {
  SeriesDetailProvider._({
    required SeriesDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seriesDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seriesDetailHash();

  @override
  String toString() {
    return r'seriesDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SeriesDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeriesDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return seriesDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seriesDetailHash() => r'87164dd31d00dee75f221f0b5e17667aec2903ea';

final class SeriesDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SeriesDetail?>, String> {
  SeriesDetailFamily._()
    : super(
        retry: null,
        name: r'seriesDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeriesDetailProvider call(String seriesId) =>
      SeriesDetailProvider._(argument: seriesId, from: this);

  @override
  String toString() => r'seriesDetailProvider';
}

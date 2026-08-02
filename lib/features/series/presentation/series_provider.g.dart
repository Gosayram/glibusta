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

String _$allSeriesHash() => r'3c1478133921383eb1463670b0b5f753c1949684';

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

String _$seriesDetailHash() => r'e206a63688c3cb58aa8ecb31c2904b19bb576354';

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

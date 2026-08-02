// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(readingStats)
final readingStatsProvider = ReadingStatsProvider._();

final class ReadingStatsProvider
    extends $FunctionalProvider<AsyncValue<ReadingStats>, ReadingStats, FutureOr<ReadingStats>>
    with $FutureModifier<ReadingStats>, $FutureProvider<ReadingStats> {
  ReadingStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingStatsHash();

  @$internal
  @override
  $FutureProviderElement<ReadingStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReadingStats> create(Ref ref) {
    return readingStats(ref);
  }
}

String _$readingStatsHash() => r'67d38532b00b9df673f2b0c5d3342b1a14bb5255';

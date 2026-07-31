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

String _$readingStatsHash() => r'532eee86c4de488450e226442f7b3f89ccd8b2e6';

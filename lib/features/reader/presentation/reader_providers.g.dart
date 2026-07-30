// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReaderSettingsNotifier)
final readerSettingsProvider = ReaderSettingsNotifierProvider._();

final class ReaderSettingsNotifierProvider
    extends $NotifierProvider<ReaderSettingsNotifier, ReaderSettings> {
  ReaderSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerSettingsNotifierHash();

  @$internal
  @override
  ReaderSettingsNotifier create() => ReaderSettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReaderSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReaderSettings>(value),
    );
  }
}

String _$readerSettingsNotifierHash() => r'35492007fb915a473f7f3253a4a5855e69538205';

abstract class _$ReaderSettingsNotifier extends $Notifier<ReaderSettings> {
  ReaderSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReaderSettings, ReaderSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReaderSettings, ReaderSettings>,
              ReaderSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ReadingProgressNotifier)
final readingProgressProvider = ReadingProgressNotifierProvider._();

final class ReadingProgressNotifierProvider
    extends $NotifierProvider<ReadingProgressNotifier, ReadingProgress?> {
  ReadingProgressNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingProgressNotifierHash();

  @$internal
  @override
  ReadingProgressNotifier create() => ReadingProgressNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadingProgress? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadingProgress?>(value),
    );
  }
}

String _$readingProgressNotifierHash() => r'78ab1521caae67849152f0b424b3ac9ecd2a8181';

abstract class _$ReadingProgressNotifier extends $Notifier<ReadingProgress?> {
  ReadingProgress? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReadingProgress?, ReadingProgress?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReadingProgress?, ReadingProgress?>,
              ReadingProgress?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

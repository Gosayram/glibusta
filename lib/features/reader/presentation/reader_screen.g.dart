// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_screen.dart';

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

String _$readerSettingsNotifierHash() =>
    r'c82c7258c1c0db7fa8fede2720871e8a0b3b1bd6';

abstract class _$ReaderSettingsNotifier extends $Notifier<ReaderSettings> {
  ReaderSettings build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ReaderSettings, ReaderSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReaderSettings, ReaderSettings>,
              ReaderSettings,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
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

String _$readingProgressNotifierHash() =>
    r'0f4074774f2008adb8e9ce89b26c4777d9d3ac81';

abstract class _$ReadingProgressNotifier extends $Notifier<ReadingProgress?> {
  ReadingProgress? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ReadingProgress?, ReadingProgress?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReadingProgress?, ReadingProgress?>,
              ReadingProgress?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

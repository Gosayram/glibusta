// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReadingInfoNotifier)
final readingInfoProvider = ReadingInfoNotifierProvider._();

final class ReadingInfoNotifierProvider
    extends $NotifierProvider<ReadingInfoNotifier, ReadingInfoModel> {
  ReadingInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingInfoNotifierHash();

  @$internal
  @override
  ReadingInfoNotifier create() => ReadingInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadingInfoModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadingInfoModel>(value),
    );
  }
}

String _$readingInfoNotifierHash() =>
    r'5600b02e82e08e515dee7d29098d155f87dc3b65';

abstract class _$ReadingInfoNotifier extends $Notifier<ReadingInfoModel> {
  ReadingInfoModel build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReadingInfoModel, ReadingInfoModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReadingInfoModel, ReadingInfoModel>,
              ReadingInfoModel,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

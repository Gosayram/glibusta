// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StorageModeNotifier)
final storageModeProvider = StorageModeNotifierProvider._();

final class StorageModeNotifierProvider
    extends $NotifierProvider<StorageModeNotifier, StorageMode> {
  StorageModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageModeNotifierHash();

  @$internal
  @override
  StorageModeNotifier create() => StorageModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageMode>(value),
    );
  }
}

String _$storageModeNotifierHash() =>
    r'f565d290b02fc7d5bc6d584bac636ce0f367bd3d';

abstract class _$StorageModeNotifier extends $Notifier<StorageMode> {
  StorageMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StorageMode, StorageMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StorageMode, StorageMode>,
              StorageMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ExternalFolderNotifier)
final externalFolderProvider = ExternalFolderNotifierProvider._();

final class ExternalFolderNotifierProvider
    extends
        $NotifierProvider<
          ExternalFolderNotifier,
          ({String? name, String? uri})
        > {
  ExternalFolderNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalFolderNotifierHash();

  @$internal
  @override
  ExternalFolderNotifier create() => ExternalFolderNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({String? name, String? uri}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({String? name, String? uri})>(
        value,
      ),
    );
  }
}

String _$externalFolderNotifierHash() =>
    r'1329b12b2371f34846fe35ce53e0161525a2b4a6';

abstract class _$ExternalFolderNotifier
    extends $Notifier<({String? name, String? uri})> {
  ({String? name, String? uri}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String? name, String? uri}),
              ({String? name, String? uri})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String? name, String? uri}),
                ({String? name, String? uri})
              >,
              ({String? name, String? uri}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DirectReadNotifier)
final directReadProvider = DirectReadNotifierProvider._();

final class DirectReadNotifierProvider
    extends $NotifierProvider<DirectReadNotifier, bool> {
  DirectReadNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directReadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directReadNotifierHash();

  @$internal
  @override
  DirectReadNotifier create() => DirectReadNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$directReadNotifierHash() =>
    r'4ea7ffc9d7e931d3d0fdfb4cd1e6e78657a5b721';

abstract class _$DirectReadNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

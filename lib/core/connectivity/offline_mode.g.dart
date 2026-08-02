// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadPolicyPersistence)
final downloadPolicyPersistenceProvider = DownloadPolicyPersistenceProvider._();

final class DownloadPolicyPersistenceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadPolicyPersistence>,
          DownloadPolicyPersistence,
          FutureOr<DownloadPolicyPersistence>
        >
    with $FutureModifier<DownloadPolicyPersistence>, $FutureProvider<DownloadPolicyPersistence> {
  DownloadPolicyPersistenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadPolicyPersistenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadPolicyPersistenceHash();

  @$internal
  @override
  $FutureProviderElement<DownloadPolicyPersistence> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadPolicyPersistence> create(Ref ref) {
    return downloadPolicyPersistence(ref);
  }
}

String _$downloadPolicyPersistenceHash() => r'c622c4ae3cbc12dec527846d11ed61772b2a10fc';

@ProviderFor(AllowMobileDownloadsNotifier)
final allowMobileDownloadsProvider = AllowMobileDownloadsNotifierProvider._();

final class AllowMobileDownloadsNotifierProvider
    extends $NotifierProvider<AllowMobileDownloadsNotifier, bool> {
  AllowMobileDownloadsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allowMobileDownloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allowMobileDownloadsNotifierHash();

  @$internal
  @override
  AllowMobileDownloadsNotifier create() => AllowMobileDownloadsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$allowMobileDownloadsNotifierHash() => r'9deba5ca33cfb6f5ed7bc0339f034f541ddb1a56';

abstract class _$AllowMobileDownloadsNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AutoResumeOnWifiNotifier)
final autoResumeOnWifiProvider = AutoResumeOnWifiNotifierProvider._();

final class AutoResumeOnWifiNotifierProvider
    extends $NotifierProvider<AutoResumeOnWifiNotifier, bool> {
  AutoResumeOnWifiNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoResumeOnWifiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoResumeOnWifiNotifierHash();

  @$internal
  @override
  AutoResumeOnWifiNotifier create() => AutoResumeOnWifiNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$autoResumeOnWifiNotifierHash() => r'244c44147941256ac70ca89bfeaed7475555c789';

abstract class _$AutoResumeOnWifiNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(networkState)
final networkStateProvider = NetworkStateProvider._();

final class NetworkStateProvider
    extends $FunctionalProvider<AsyncValue<NetworkState>, NetworkState, Stream<NetworkState>>
    with $FutureModifier<NetworkState>, $StreamProvider<NetworkState> {
  NetworkStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkStateHash();

  @$internal
  @override
  $StreamProviderElement<NetworkState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NetworkState> create(Ref ref) {
    return networkState(ref);
  }
}

String _$networkStateHash() => r'eeddc3c092daba16b9680135cb45cb4e5a9e2f62';

@ProviderFor(currentNetwork)
final currentNetworkProvider = CurrentNetworkProvider._();

final class CurrentNetworkProvider
    extends $FunctionalProvider<AsyncValue<NetworkState>, NetworkState, FutureOr<NetworkState>>
    with $FutureModifier<NetworkState>, $FutureProvider<NetworkState> {
  CurrentNetworkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentNetworkProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentNetworkHash();

  @$internal
  @override
  $FutureProviderElement<NetworkState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NetworkState> create(Ref ref) {
    return currentNetwork(ref);
  }
}

String _$currentNetworkHash() => r'a26be1fa1f11acf53deb2404ace2b8bfd2c0b322';

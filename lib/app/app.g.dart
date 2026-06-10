// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(IsObscuredNotifier)
final isObscuredProvider = IsObscuredNotifierProvider._();

final class IsObscuredNotifierProvider extends $NotifierProvider<IsObscuredNotifier, bool> {
  IsObscuredNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isObscuredProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isObscuredNotifierHash();

  @$internal
  @override
  IsObscuredNotifier create() => IsObscuredNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isObscuredNotifierHash() => r'cb5aa3a9ed32a591bf2ef66dbc617dbff655a215';

abstract class _$IsObscuredNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

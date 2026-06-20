// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(featureFlags)
final featureFlagsProvider = FeatureFlagsProvider._();

final class FeatureFlagsProvider
    extends
        $FunctionalProvider<Map<FeatureFlag, bool>, Map<FeatureFlag, bool>, Map<FeatureFlag, bool>>
    with $Provider<Map<FeatureFlag, bool>> {
  FeatureFlagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsHash();

  @$internal
  @override
  $ProviderElement<Map<FeatureFlag, bool>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<FeatureFlag, bool> create(Ref ref) {
    return featureFlags(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<FeatureFlag, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<FeatureFlag, bool>>(value),
    );
  }
}

String _$featureFlagsHash() => r'e2924382684e12ca7667d141220239c67e5cb258';

@ProviderFor(isFlagEnabled)
final isFlagEnabledProvider = IsFlagEnabledFamily._();

final class IsFlagEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  IsFlagEnabledProvider._({
    required IsFlagEnabledFamily super.from,
    required FeatureFlag super.argument,
  }) : super(
         retry: null,
         name: r'isFlagEnabledProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFlagEnabledHash();

  @override
  String toString() {
    return r'isFlagEnabledProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as FeatureFlag;
    return isFlagEnabled(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsFlagEnabledProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFlagEnabledHash() => r'8af5b4125099d91280d91d10474d51c08814f9aa';

final class IsFlagEnabledFamily extends $Family with $FunctionalFamilyOverride<bool, FeatureFlag> {
  IsFlagEnabledFamily._()
    : super(
        retry: null,
        name: r'isFlagEnabledProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  IsFlagEnabledProvider call(FeatureFlag flag) =>
      IsFlagEnabledProvider._(argument: flag, from: this);

  @override
  String toString() => r'isFlagEnabledProvider';
}

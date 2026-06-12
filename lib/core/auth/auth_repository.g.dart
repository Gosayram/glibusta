// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthStateNotifier)
final authStateProvider = AuthStateNotifierProvider._();

final class AuthStateNotifierProvider
    extends $AsyncNotifierProvider<AuthStateNotifier, AuthStateData> {
  AuthStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateNotifierHash();

  @$internal
  @override
  AuthStateNotifier create() => AuthStateNotifier();
}

String _$authStateNotifierHash() => r'259a66d4c2b1d743150c11c958a64d8719030f45';

abstract class _$AuthStateNotifier extends $AsyncNotifier<AuthStateData> {
  FutureOr<AuthStateData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AuthStateData>, AuthStateData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AuthStateData>, AuthStateData>,
              AsyncValue<AuthStateData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

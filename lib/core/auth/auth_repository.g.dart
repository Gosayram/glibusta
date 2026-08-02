// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserSession _$UserSessionFromJson(Map<String, dynamic> json) => UserSession(
  name: json['name'] as String,
  mail: json['mail'] as String?,
  cookies:
      (json['cookies'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$UserSessionToJson(UserSession instance) =>
    <String, dynamic>{
      'name': instance.name,
      'mail': instance.mail,
      'cookies': instance.cookies,
    };

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

String _$authStateNotifierHash() => r'4aba9a6c8fadca20af50934b3e8c5b78ae1c8cdd';

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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'author_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authorDetail)
final authorDetailProvider = AuthorDetailFamily._();

final class AuthorDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<AuthorDetailResponse>,
          AuthorDetailResponse,
          FutureOr<AuthorDetailResponse>
        >
    with
        $FutureModifier<AuthorDetailResponse>,
        $FutureProvider<AuthorDetailResponse> {
  AuthorDetailProvider._({
    required AuthorDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'authorDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$authorDetailHash();

  @override
  String toString() {
    return r'authorDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AuthorDetailResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AuthorDetailResponse> create(Ref ref) {
    final argument = this.argument as String;
    return authorDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AuthorDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$authorDetailHash() => r'38d521476bd11fba376b29d5656a28b71962e326';

final class AuthorDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AuthorDetailResponse>, String> {
  AuthorDetailFamily._()
    : super(
        retry: null,
        name: r'authorDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AuthorDetailProvider call(String authorId) =>
      AuthorDetailProvider._(argument: authorId, from: this);

  @override
  String toString() => r'authorDetailProvider';
}

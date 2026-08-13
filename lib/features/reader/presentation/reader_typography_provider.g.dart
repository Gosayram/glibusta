// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_typography_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReaderTypographyNotifier)
final readerTypographyProvider = ReaderTypographyNotifierFamily._();

final class ReaderTypographyNotifierProvider
    extends $NotifierProvider<ReaderTypographyNotifier, ReaderTypography> {
  ReaderTypographyNotifierProvider._({
    required ReaderTypographyNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'readerTypographyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerTypographyNotifierHash();

  @override
  String toString() {
    return r'readerTypographyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReaderTypographyNotifier create() => ReaderTypographyNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReaderTypography value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReaderTypography>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderTypographyNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerTypographyNotifierHash() => r'e5e0d088c7f7a5dc6617201578465cc8297ecb4f';

final class ReaderTypographyNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ReaderTypographyNotifier,
          ReaderTypography,
          ReaderTypography,
          ReaderTypography,
          String
        > {
  ReaderTypographyNotifierFamily._()
    : super(
        retry: null,
        name: r'readerTypographyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReaderTypographyNotifierProvider call(String bookId) =>
      ReaderTypographyNotifierProvider._(argument: bookId, from: this);

  @override
  String toString() => r'readerTypographyProvider';
}

abstract class _$ReaderTypographyNotifier extends $Notifier<ReaderTypography> {
  late final _$args = ref.$arg as String;
  String get bookId => _$args;

  ReaderTypography build(String bookId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReaderTypography, ReaderTypography>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReaderTypography, ReaderTypography>,
              ReaderTypography,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

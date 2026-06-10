// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_view_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryViewModeNotifier)
final libraryViewModeProvider = LibraryViewModeNotifierProvider._();

final class LibraryViewModeNotifierProvider
    extends $NotifierProvider<LibraryViewModeNotifier, LibraryViewMode> {
  LibraryViewModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryViewModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryViewModeNotifierHash();

  @$internal
  @override
  LibraryViewModeNotifier create() => LibraryViewModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryViewMode>(value),
    );
  }
}

String _$libraryViewModeNotifierHash() =>
    r'a6b311d601d0388644a9dfe95f6855161781ac99';

abstract class _$LibraryViewModeNotifier extends $Notifier<LibraryViewMode> {
  LibraryViewMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LibraryViewMode, LibraryViewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryViewMode, LibraryViewMode>,
              LibraryViewMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

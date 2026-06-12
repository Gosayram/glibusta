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
    extends $AsyncNotifierProvider<LibraryViewModeNotifier, LibraryViewMode> {
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
}

String _$libraryViewModeNotifierHash() => r'007c66e1a8f8e620a1d917cebf2b23ff81b55bea';

abstract class _$LibraryViewModeNotifier extends $AsyncNotifier<LibraryViewMode> {
  FutureOr<LibraryViewMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LibraryViewMode>, LibraryViewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LibraryViewMode>, LibraryViewMode>,
              AsyncValue<LibraryViewMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

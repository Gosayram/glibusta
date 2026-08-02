// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'color_preset_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ColorPresetList)
final colorPresetListProvider = ColorPresetListProvider._();

final class ColorPresetListProvider
    extends $AsyncNotifierProvider<ColorPresetList, List<ColorPreset>> {
  ColorPresetListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'colorPresetListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$colorPresetListHash();

  @$internal
  @override
  ColorPresetList create() => ColorPresetList();
}

String _$colorPresetListHash() => r'8e9dae3da06c704ca5033fa5c443f785809dd3ee';

abstract class _$ColorPresetList extends $AsyncNotifier<List<ColorPreset>> {
  FutureOr<List<ColorPreset>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ColorPreset>>, List<ColorPreset>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ColorPreset>>, List<ColorPreset>>,
              AsyncValue<List<ColorPreset>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

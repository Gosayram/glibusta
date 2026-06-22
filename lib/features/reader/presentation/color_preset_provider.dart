import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/color_preset_service.dart';

part 'color_preset_provider.g.dart';

@riverpod
class ColorPresetList extends _$ColorPresetList {
  @override
  Future<List<ColorPreset>> build() async {
    return ColorPresetService.load();
  }

  Future<void> add(ColorPreset preset) async {
    final current = await future;
    final updated = [...current, preset];
    await ColorPresetService.save(updated);
    state = AsyncData(updated);
  }

  Future<void> updatePreset(ColorPreset preset) async {
    final current = await future;
    final updated = [
      for (final p in current)
        if (p.id == preset.id) preset else p,
    ];
    await ColorPresetService.save(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final current = await future;
    final updated = current.where((p) => p.id != id).toList();
    await ColorPresetService.save(updated);
    state = AsyncData(updated);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = await future;
    final list = List<ColorPreset>.from(current);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await ColorPresetService.save(list);
    state = AsyncData(list);
  }
}

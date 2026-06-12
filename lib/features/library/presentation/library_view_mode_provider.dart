import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'library_view_mode_provider.g.dart';

enum LibraryViewMode { grid, list, compact }

@riverpod
class LibraryViewModeNotifier extends _$LibraryViewModeNotifier {
  static const _key = 'library_view_mode';

  @override
  Future<LibraryViewMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    if (index >= 0 && index < LibraryViewMode.values.length) {
      return LibraryViewMode.values[index];
    }
    return LibraryViewMode.grid;
  }

  Future<void> setMode(LibraryViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
    state = AsyncData(mode);
  }

  Future<void> cycle() async {
    final current = await future;
    final next = (current.index + 1) % LibraryViewMode.values.length;
    await setMode(LibraryViewMode.values[next]);
  }
}

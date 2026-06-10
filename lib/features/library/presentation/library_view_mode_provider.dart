import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'library_view_mode_provider.g.dart';

enum LibraryViewMode { grid, list, compact }

@riverpod
class LibraryViewModeNotifier extends _$LibraryViewModeNotifier {
  static const _key = 'library_view_mode';

  @override
  LibraryViewMode build() {
    unawaited(_loadFromPrefs());
    return LibraryViewMode.grid;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    if (index >= 0 && index < LibraryViewMode.values.length) {
      state = LibraryViewMode.values[index];
    }
  }

  Future<void> setMode(LibraryViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }

  void cycle() {
    final next = (state.index + 1) % LibraryViewMode.values.length;
    unawaited(setMode(LibraryViewMode.values[next]));
  }
}

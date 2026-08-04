import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/reading_info_model.dart';

part 'reading_info_provider.g.dart';

const _key = 'reading_info_config';

@riverpod
class ReadingInfoNotifier extends _$ReadingInfoNotifier {
  var _version = 0;
  var _loaded = false;

  @override
  ReadingInfoModel build() {
    unawaited(_load());
    return ReadingInfoModel.defaults;
  }

  Future<void> _load() async {
    final version = _version;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || version != _version) return;
      final json = prefs.getString(_key);
      if (json != null) {
        state = ReadingInfoModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map),
        );
      }
      _loaded = true;
    } on Object catch (_) {
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } on Object catch (_) {}
  }

  // ponytail: one update() replaces 6 slot-specific methods
  void update(ReadingInfoModel Function(ReadingInfoModel) fn) {
    ++_version;
    state = fn(state);
    unawaited(_save());
  }

  void updateFontSize(double size) {
    ++_version;
    state = state.copyWith(fontSize: size);
    unawaited(_save());
  }

  void updateMargin(double margin) {
    ++_version;
    state = state.copyWith(margin: margin);
    unawaited(_save());
  }

  void reset() {
    ++_version;
    state = ReadingInfoModel.defaults;
    unawaited(_save());
  }
}

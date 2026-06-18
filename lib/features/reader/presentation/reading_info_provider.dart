import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/reading_info_model.dart';

part 'reading_info_provider.g.dart';

const _key = 'reading_info_config';

@riverpod
class ReadingInfoNotifier extends _$ReadingInfoNotifier {
  @override
  ReadingInfoModel build() {
    _load();
    return ReadingInfoModel.defaults;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        state = ReadingInfoModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map),
        );
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void updateHeaderLeft(InfoSlotMode mode) {
    state = state.copyWith(headerLeft: mode);
    _save();
  }

  void updateHeaderCenter(InfoSlotMode mode) {
    state = state.copyWith(headerCenter: mode);
    _save();
  }

  void updateHeaderRight(InfoSlotMode mode) {
    state = state.copyWith(headerRight: mode);
    _save();
  }

  void updateFooterLeft(InfoSlotMode mode) {
    state = state.copyWith(footerLeft: mode);
    _save();
  }

  void updateFooterCenter(InfoSlotMode mode) {
    state = state.copyWith(footerCenter: mode);
    _save();
  }

  void updateFooterRight(InfoSlotMode mode) {
    state = state.copyWith(footerRight: mode);
    _save();
  }

  void updateFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _save();
  }

  void updateMargin(double margin) {
    state = state.copyWith(margin: margin);
    _save();
  }

  void reset() {
    state = ReadingInfoModel.defaults;
    _save();
  }
}

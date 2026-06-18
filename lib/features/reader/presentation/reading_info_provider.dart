import 'dart:async';
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
    unawaited(_load());
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
    } on Object catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } on Object catch (_) {}
  }

  void updateHeaderLeft(InfoSlotMode mode) {
    state = state.copyWith(headerLeft: mode);
    unawaited(_save());
  }

  void updateHeaderCenter(InfoSlotMode mode) {
    state = state.copyWith(headerCenter: mode);
    unawaited(_save());
  }

  void updateHeaderRight(InfoSlotMode mode) {
    state = state.copyWith(headerRight: mode);
    unawaited(_save());
  }

  void updateFooterLeft(InfoSlotMode mode) {
    state = state.copyWith(footerLeft: mode);
    unawaited(_save());
  }

  void updateFooterCenter(InfoSlotMode mode) {
    state = state.copyWith(footerCenter: mode);
    unawaited(_save());
  }

  void updateFooterRight(InfoSlotMode mode) {
    state = state.copyWith(footerRight: mode);
    unawaited(_save());
  }

  void updateFontSize(double size) {
    state = state.copyWith(fontSize: size);
    unawaited(_save());
  }

  void updateMargin(double margin) {
    state = state.copyWith(margin: margin);
    unawaited(_save());
  }

  void reset() {
    state = ReadingInfoModel.defaults;
    unawaited(_save());
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/reader/domain/reader.dart';

class CustomFontHelper {
  static const _familyKey = 'custom_font_family';
  static const _pathKey = 'custom_font_path';

  static Future<String?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey);
    final family = prefs.getString(_familyKey);
    if (path == null || family == null) return null;
    final loaded = await _loadAndActivate(path, family);
    if (loaded) return family;
    await prefs.remove(_pathKey);
    await prefs.remove(_familyKey);
    return null;
  }

  static Future<bool> pickAndLoad(String path, String familyName) async {
    final loaded = await _loadAndActivate(path, familyName);
    if (!loaded) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyKey, familyName);
    await prefs.setString(_pathKey, path);
    return true;
  }

  static Future<bool> _loadAndActivate(String path, String familyName) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.view(bytes.buffer, 0, bytes.length)));
      await loader.load();
      ReaderFont.activeCustomFontFamily = familyName;
      return true;
    } on Object catch (_) {
      return false;
    }
  }
}

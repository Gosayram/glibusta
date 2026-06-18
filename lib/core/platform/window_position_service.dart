import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

class WindowPositionService {
  WindowPositionService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'window_position';

  Rect? getSavedBounds() {
    final json = _prefs.getString(_key);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return Rect.fromLTWH(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      );
    } catch (e) {
      AppLogger.debug('Failed to parse window position: $e');
      return null;
    }
  }

  bool getIsMaximized() {
    return _prefs.getBool('${_key}_maximized') ?? false;
  }

  Future<void> saveBounds(Rect bounds, {bool maximized = false}) async {
    final map = {
      'x': bounds.left,
      'y': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    };
    await _prefs.setString(_key, jsonEncode(map));
    await _prefs.setBool('${_key}_maximized', maximized);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    await _prefs.remove('${_key}_maximized');
  }

  static Rect? validateBounds(Rect bounds, Size screenSize) {
    if (bounds.width <= 0 || bounds.height <= 0) return null;
    final clampedLeft = bounds.left.clamp(0.0, screenSize.width - 200);
    final clampedTop = bounds.top.clamp(0.0, screenSize.height - 200);
    final clampedWidth = bounds.width.clamp(400.0, screenSize.width);
    final clampedHeight = bounds.height.clamp(300.0, screenSize.height);
    return Rect.fromLTWH(clampedLeft, clampedTop, clampedWidth, clampedHeight);
  }
}

final windowPositionServiceProvider = Provider<WindowPositionService>((ref) {
  throw UnimplementedError(
    'windowPositionServiceProvider must be overridden at startup. '
    'Requires window_manager package to be added to pubspec.yaml.',
  );
});

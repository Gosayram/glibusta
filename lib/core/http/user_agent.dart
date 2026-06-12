import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceUserAgent {
  DeviceUserAgent._();

  static const _prefsKey = 'device_user_agent';
  static const _chromeVersion = '131.0.6778.81';

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null) return cached;

    final ua = await _generate();
    await prefs.setString(_prefsKey, ua);
    return ua;
  }

  static Future<String> _generate() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (_isAndroid) {
        return _androidUA(await deviceInfo.androidInfo);
      }
      if (_isIOS) {
        return _iosUA(await deviceInfo.iosInfo);
      }
    } on Object {}
    return _fallbackUA();
  }

  static bool get _isAndroid {
    return const bool.fromEnvironment('dart.library.io') &&
        !const bool.fromEnvironment('dart.library.html');
  }

  static bool get _isIOS {
    return false;
  }

  static String _androidUA(AndroidDeviceInfo info) {
    final version = info.version.release;
    final model = info.model;

    final chromeBuild = _generateChromeBuild(model, info.version.sdkInt);

    return 'Mozilla/5.0 (Linux; Android $version; $model Build/$chromeBuild; wv) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Version/4.0 Chrome/$_chromeVersion Mobile Safari/537.36';
  }

  static String _iosUA(IosDeviceInfo info) {
    final version = info.systemVersion;
    final model = info.model;
    final systemName = info.systemName;

    return 'Mozilla/5.0 ($systemName; $model; iOS $version) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) '
        'Version/18.2 Mobile/15E148 Safari/604.1';
  }

  static String _fallbackUA() {
    final r = Random();
    final versions = ['12', '13', '14', '15'];
    final models = ['SM-G991B', 'Pixel 8', 'SM-S918B', '22111317G', 'CPH2413'];
    final version = versions[r.nextInt(versions.length)];
    final model = models[r.nextInt(models.length)];

    return 'Mozilla/5.0 (Linux; Android $version; $model) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Version/4.0 Chrome/$_chromeVersion Mobile Safari/537.36';
  }

  static String _generateChromeBuild(String model, int sdk) {
    final safeModel = model.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final r = Random(safeModel.hashCode ^ sdk);
    final buildNum = 1000000000 + r.nextInt(900000000);
    return 'TP1A.$buildNum.015';
  }
}

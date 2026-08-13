import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reader.dart';

final autoThemeServiceProvider = Provider<AutoThemeService>((ref) => AutoThemeService());

final class AutoThemeService {
  ReaderTheme resolveTheme(
    AutoThemeMode mode,
    ReaderTheme manualTheme, {
    DateTime? now,
    int customDayHour = 7,
    int customNightHour = 20,
    ReaderTheme nightTheme = ReaderTheme.dark,
  }) {
    if (mode == AutoThemeMode.off) return manualTheme;
    final dt = now ?? DateTime.now();
    final isNight = _isNight(mode, dt, customDayHour, customNightHour);
    return isNight ? nightTheme : ReaderTheme.light;
  }

  double resolveWarmth(AutoThemeMode mode, ReaderTheme resolvedTheme, {DateTime? now}) {
    if (mode == AutoThemeMode.off) return 0.0;
    if (resolvedTheme == ReaderTheme.bedtime) return 0.6;
    if (resolvedTheme == ReaderTheme.dark || resolvedTheme == ReaderTheme.oled) return 0.15;
    return 0.0;
  }

  bool _isNight(AutoThemeMode mode, DateTime dt, int customDayHour, int customNightHour) {
    return switch (mode) {
      AutoThemeMode.off => false,
      AutoThemeMode.system => _isSystemDark(dt),
      AutoThemeMode.sunset => _isAfterSunset(dt),
      AutoThemeMode.custom => _isInCustomNight(dt, customDayHour, customNightHour),
    };
  }

  bool _isSystemDark(DateTime dt) {
    final hour = dt.hour;
    return hour < 7 || hour >= 20;
  }

  bool _isAfterSunset(DateTime dt) {
    final sunset = _calculateSunset(dt);
    final sunrise = _calculateSunrise(dt);
    final minutes = dt.hour * 60 + dt.minute;
    final sunsetMinutes = sunset.hour * 60 + sunset.minute;
    final sunriseMinutes = sunrise.hour * 60 + sunrise.minute;
    if (sunriseMinutes <= sunsetMinutes) {
      return minutes >= sunsetMinutes || minutes < sunriseMinutes;
    }
    return minutes >= sunsetMinutes && minutes < sunriseMinutes;
  }

  bool _isInCustomNight(DateTime dt, int dayHour, int nightHour) {
    final hour = dt.hour;
    if (dayHour < nightHour) {
      return hour < dayHour || hour >= nightHour;
    }
    return hour >= nightHour && hour < dayHour;
  }

  DateTime _calculateSunset(DateTime dt) {
    final dayOfYear = dt.difference(DateTime(dt.year)).inDays;
    final offset = 12.0 + 2.5 * cos((dayOfYear - 172) * 2 * pi / 365);
    final hour = offset.floor();
    final minute = ((offset - hour) * 60).round();
    return DateTime(dt.year, dt.month, dt.day, hour + 6, minute);
  }

  DateTime _calculateSunrise(DateTime dt) {
    final dayOfYear = dt.difference(DateTime(dt.year)).inDays;
    final offset = 12.0 - 2.5 * cos((dayOfYear - 172) * 2 * pi / 365);
    final hour = offset.floor();
    final minute = ((offset - hour) * 60).round();
    return DateTime(dt.year, dt.month, dt.day, hour + 6, minute);
  }
}

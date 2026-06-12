import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_settings_persistence.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReaderSettingsPersistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('load', () {
      test('returns default settings when no saved data exists', () async {
        final settings = await ReaderSettingsPersistence.load();
        expect(settings.theme, ReaderTheme.system);
        expect(settings.mode, ReaderMode.continuous);
        expect(settings.fontSize, 18.0);
        expect(settings.lineHeight, 1.55);
        expect(settings.margin, 20.0);
        expect(settings.font, ReaderFont.literata);
        expect(settings.paragraphSpacing, 8.0);
        expect(settings.letterSpacing, 0.0);
        expect(settings.textAlign, ReaderTextAlign.left);
        expect(settings.autoThemeMode, AutoThemeMode.off);
        expect(settings.customDayHour, 7);
        expect(settings.customNightHour, 20);
      });

      test('loads saved settings correctly', () async {
        const savedSettings = ReaderSettings(
          theme: ReaderTheme.sepia,
          mode: ReaderMode.paginated,
          fontSize: 22.0,
          lineHeight: 1.7,
          margin: 24.0,
          paragraphSpacing: 12.0,
          letterSpacing: 0.5,
          autoThemeMode: AutoThemeMode.sunset,
          customDayHour: 8,
          customNightHour: 21,
        );
        await ReaderSettingsPersistence.save(savedSettings);

        final loaded = await ReaderSettingsPersistence.load();
        expect(loaded.theme, ReaderTheme.sepia);
        expect(loaded.mode, ReaderMode.paginated);
        expect(loaded.fontSize, 22.0);
        expect(loaded.lineHeight, 1.7);
        expect(loaded.margin, 24.0);
        expect(loaded.font, ReaderFont.literata);
        expect(loaded.paragraphSpacing, 12.0);
        expect(loaded.letterSpacing, 0.5);
        expect(loaded.textAlign, ReaderTextAlign.left);
        expect(loaded.autoThemeMode, AutoThemeMode.sunset);
        expect(loaded.customDayHour, 8);
        expect(loaded.customNightHour, 21);
      });

      test('returns defaults for corrupted data', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reader_settings', 'not valid json {{{');

        final settings = await ReaderSettingsPersistence.load();
        expect(settings.theme, ReaderTheme.system);
        expect(settings.fontSize, 18.0);
      });

      test('returns defaults for missing fields in saved data', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'reader_settings',
          jsonEncode({'theme': 'paper'}),
        );

        final settings = await ReaderSettingsPersistence.load();
        expect(settings.theme, ReaderTheme.paper);
        expect(settings.fontSize, 18.0); // default
        expect(settings.lineHeight, 1.55); // default
      });

      test('handles unknown theme name gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'reader_settings',
          jsonEncode({'theme': 'nonexistent'}),
        );

        final settings = await ReaderSettingsPersistence.load();
        expect(settings.theme, ReaderTheme.system); // fallback
      });

      test('handles unknown font name gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'reader_settings',
          jsonEncode({'font': 'nonexistent'}),
        );

        final settings = await ReaderSettingsPersistence.load();
        expect(settings.font, ReaderFont.literata); // fallback
      });
    });

    group('save', () {
      test('persists settings to SharedPreferences', () async {
        const settings = ReaderSettings(
          theme: ReaderTheme.oled,
          fontSize: 20.0,
          font: ReaderFont.inter,
        );

        await ReaderSettingsPersistence.save(settings);
        final loaded = await ReaderSettingsPersistence.load();

        expect(loaded.theme, ReaderTheme.oled);
        expect(loaded.fontSize, 20.0);
        expect(loaded.font, ReaderFont.inter);
      });

      test('overwrites previous settings', () async {
        await ReaderSettingsPersistence.save(
          const ReaderSettings(theme: ReaderTheme.light),
        );
        await ReaderSettingsPersistence.save(
          const ReaderSettings(theme: ReaderTheme.bedtime),
        );

        final loaded = await ReaderSettingsPersistence.load();
        expect(loaded.theme, ReaderTheme.bedtime);
      });

      test('saves all fields correctly', () async {
        const settings = ReaderSettings(
          theme: ReaderTheme.sepia,
          mode: ReaderMode.twoPage,
          fontSize: 16.0,
          lineHeight: 1.3,
          margin: 8.0,
          paragraphSpacing: 4.0,
          letterSpacing: -0.3,
          textAlign: ReaderTextAlign.center,
          autoThemeMode: AutoThemeMode.custom,
          customDayHour: 6,
          customNightHour: 22,
        );

        await ReaderSettingsPersistence.save(settings);
        final loaded = await ReaderSettingsPersistence.load();

        expect(loaded.theme, ReaderTheme.sepia);
        expect(loaded.mode, ReaderMode.twoPage);
        expect(loaded.fontSize, 16.0);
        expect(loaded.lineHeight, 1.3);
        expect(loaded.margin, 8.0);
        expect(loaded.font, ReaderFont.literata);
        expect(loaded.paragraphSpacing, 4.0);
        expect(loaded.letterSpacing, -0.3);
        expect(loaded.textAlign, ReaderTextAlign.center);
        expect(loaded.autoThemeMode, AutoThemeMode.custom);
        expect(loaded.customDayHour, 6);
        expect(loaded.customNightHour, 22);
      });
    });
  });
}

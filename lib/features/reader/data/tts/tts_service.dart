import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base_tts.dart';
import 'system_tts.dart';

const _ttsSettingsKey = 'tts_settings';

class TtsService {
  TtsService(this._prefs);

  final SharedPreferences _prefs;
  late final SystemTts _tts;
  TtsSettings _settings = const TtsSettings();
  bool _initialized = false;

  BaseTts get tts => _tts;

  Future<void> init() async {
    if (_initialized) return;
    _tts = SystemTts();
    _settings = _loadSettings();
    await _tts.applySettings(_settings);
    _initialized = true;
  }

  TtsSettings _loadSettings() {
    final json = _prefs.getString(_ttsSettingsKey);
    if (json == null) return const TtsSettings();
    try {
      return TtsSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (_) {
      return const TtsSettings();
    }
  }

  Future<void> _saveSettings() async {
    await _prefs.setString(_ttsSettingsKey, jsonEncode(_settings.toJson()));
  }

  TtsSettings get settings => _settings;

  Future<void> updateSettings(TtsSettings settings) async {
    _settings = settings;
    await _tts.applySettings(settings);
    await _saveSettings();
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<void> resume() async {
    await _tts.resume();
  }

  Future<void> dispose() async {
    await _tts.dispose();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = TtsService(prefs);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at startup.',
  );
});

final ttsStateProvider = NotifierProvider<TtsStateNotifier, TtsState>(
  TtsStateNotifier.new,
);

class TtsStateNotifier extends Notifier<TtsState> {
  @override
  TtsState build() => TtsState.stopped;

  void update(TtsState value) => state = value;
}

final ttsSentenceProvider = NotifierProvider<TtsSentenceNotifier, int>(
  TtsSentenceNotifier.new,
);

class TtsSentenceNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void update(int value) => state = value;
}

final ttsSleepTimerProvider = Provider<TtsSleepTimer>((ref) {
  final timer = TtsSleepTimer();
  ref.onDispose(timer.dispose);
  return timer;
});

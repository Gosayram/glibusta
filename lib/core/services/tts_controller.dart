import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// LW-11.1/11.2: TTS controller with headphone auto-pause/resume.
/// ponytail: singleton — single TTS instance shared across app.
class TtsController {
  TtsController._({
    FlutterTts Function()? ttsFactory,
    Timer Function(Duration, void Function())? timerFactory,
  }) : _ttsFactory = ttsFactory ?? FlutterTts.new,
       _timerFactory = timerFactory ?? Timer.new;
  static final TtsController instance = TtsController._();

  @visibleForTesting
  TtsController.forTesting(
    FlutterTts Function() ttsFactory, {
    Timer Function(Duration, void Function())? timerFactory,
  }) : _ttsFactory = ttsFactory,
       _timerFactory = timerFactory ?? Timer.new;

  final FlutterTts Function() _ttsFactory;
  final Timer Function(Duration, void Function()) _timerFactory;
  late FlutterTts _tts;
  var _isTtsInitialized = false;
  bool _isPlaying = false;
  late String _lastLang;
  late double _lastRate;
  String? _lastText;
  StreamSubscription<dynamic>? _noisySub;
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;
  var _sleepTimerGeneration = 0;

  void _ensureTts() {
    if (_isTtsInitialized) return;

    _tts = _ttsFactory();
    _lastLang = 'ru-RU';
    _lastRate = 0.5;
    _isTtsInitialized = true;
  }

  /// Start listening for headphone removal events.
  Future<void> init() async {
    if (_noisySub != null) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        if (_isPlaying) {
          stop();
          debugPrint('TTS auto-paused: headphone removed');
        }
      });
    } on Object catch (e) {
      debugPrint('TTS headphone listener failed: $e');
    }
  }

  Future<void> speak(String text, {String? lang, double? rate}) async {
    _ensureTts();
    _lastText = text;
    if (lang != null) _lastLang = lang;
    if (rate != null) _lastRate = rate;
    await _tts.setLanguage(_lastLang);
    await _tts.setSpeechRate(_lastRate);
    _isPlaying = true;
    await _tts.speak(text);
  }

  /// Resume speaking last text.
  Future<void> resume() async {
    if (_lastText != null) {
      await speak(_lastText!, lang: _lastLang, rate: _lastRate);
    }
  }

  void stop() {
    _isPlaying = false;
    if (_isTtsInitialized) {
      _tts.stop(); // ignore: discarded_futures
    }
  }

  bool get isPlaying => _isPlaying;

  bool get hasLastText => _lastText != null;

  /// Stops speech after [duration]. Starting a new timer replaces the old one.
  void startSleepTimer(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be greater than zero');
    }

    cancelSleepTimer();
    final int generation = ++_sleepTimerGeneration;
    _sleepTimerDuration = duration;
    _sleepTimer = _timerFactory(duration, () {
      if (generation != _sleepTimerGeneration) return;

      _sleepTimer = null;
      _sleepTimerDuration = null;
      stop();
    });
  }

  /// Cancels the pending sleep timer without changing current speech.
  void cancelSleepTimer() {
    _sleepTimerGeneration++;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerDuration = null;
  }

  /// Whether a timer is currently scheduled to stop speech.
  bool get hasSleepTimer => _sleepTimer != null;

  /// Initially scheduled duration for the active sleep timer.
  Duration? get sleepTimerDuration => _sleepTimerDuration;

  void dispose() {
    cancelSleepTimer();
    _noisySub?.cancel(); // ignore: discarded_futures
    _noisySub = null;
    _lastText = null;
    if (_isTtsInitialized) {
      _tts.stop(); // ignore: discarded_futures
    }
    _isPlaying = false;
  }
}

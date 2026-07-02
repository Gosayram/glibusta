import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// LW-11.1/11.2: TTS controller with headphone auto-pause/resume.
/// ponytail: singleton — single TTS instance shared across app.
class TtsController {
  TtsController._();
  static final TtsController instance = TtsController._();

  late FlutterTts _tts;
  bool _isPlaying = false;
  late String _lastLang;
  late double _lastRate;
  StreamSubscription<dynamic>? _noisySub;

  void _ensureTts() {
    _tts = FlutterTts();
    _lastLang = 'ru-RU';
    _lastRate = 0.5;
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
    if (lang != null) _lastLang = lang;
    if (rate != null) _lastRate = rate;
    await _tts.setLanguage(_lastLang);
    await _tts.setSpeechRate(_lastRate);
    _isPlaying = true;
    await _tts.speak(text);
  }

  void stop() {
    _isPlaying = false;
    _tts.stop(); // ignore: discarded_futures
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _noisySub?.cancel(); // ignore: discarded_futures
    _noisySub = null;
    _tts.stop(); // ignore: discarded_futures
    _isPlaying = false;
  }
}

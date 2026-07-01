import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// LW-11.1/11.2: TTS controller with headphone auto-pause/resume.
/// ponytail: singleton — single TTS instance shared across app.
class TtsController {
  TtsController._();
  static final TtsController instance = TtsController._();

  FlutterTts? _tts;
  bool _isPlaying = false;
  String? _lastText;
  String _lastLang = 'ru-RU';
  double _lastRate = 0.5;
  StreamSubscription<dynamic>? _noisySub;

  Future<FlutterTts> _ensureTts() async {
    _tts ??= FlutterTts();
    return _tts!;
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
    final tts = await _ensureTts();
    _lastText = text;
    if (lang != null) _lastLang = lang;
    if (rate != null) _lastRate = rate;
    await tts.setLanguage(_lastLang);
    await tts.setSpeechRate(_lastRate);
    _isPlaying = true;
    await tts.speak(text);
  }

  void stop() {
    _isPlaying = false;
    _tts?.stop();
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _noisySub?.cancel();
    _noisySub = null;
    _tts?.stop();
    _isPlaying = false;
  }
}

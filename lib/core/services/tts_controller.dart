import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// LW-11.1/11.2: TTS controller with headphone auto-pause/resume.
/// ponytail: singleton — single TTS instance shared across app.
class TtsController {
  TtsController._({FlutterTts Function()? ttsFactory}) : _ttsFactory = ttsFactory ?? FlutterTts.new;
  static final TtsController instance = TtsController._();

  @visibleForTesting
  TtsController.forTesting(FlutterTts Function() ttsFactory) : _ttsFactory = ttsFactory;

  final FlutterTts Function() _ttsFactory;
  late FlutterTts _tts;
  var _isTtsInitialized = false;
  bool _isPlaying = false;
  late String _lastLang;
  late double _lastRate;
  String? _lastText;
  StreamSubscription<dynamic>? _noisySub;

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

  void dispose() {
    _noisySub?.cancel(); // ignore: discarded_futures
    _noisySub = null;
    _lastText = null;
    if (_isTtsInitialized) {
      _tts.stop(); // ignore: discarded_futures
    }
    _isPlaying = false;
  }
}

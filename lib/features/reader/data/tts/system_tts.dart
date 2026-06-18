import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'base_tts.dart';

class SystemTts extends BaseTts {
  SystemTts() {
    unawaited(_init());
  }

  final _tts = FlutterTts();
  final _stateController = StreamController<TtsState>.broadcast();
  final _sentenceController = StreamController<int>.broadcast();

  TtsSettings _settings = const TtsSettings();
  List<TtsSegment> _segments = [];
  int _currentSegmentIndex = 0;

  @override
  Stream<TtsState> get onStateChange => _stateController.stream;

  @override
  Stream<int> get onSentenceIndex => _sentenceController.stream;

  Future<void> _init() async {
    _tts.setStartHandler(() {
      _stateController.add(TtsState.playing);
    });

    _tts.setCompletionHandler(() {
      _stateController.add(TtsState.stopped);
    });

    _tts.setCancelHandler(() {
      _stateController.add(TtsState.stopped);
    });

    _tts.setPauseHandler(() {
      _stateController.add(TtsState.paused);
    });

    _tts.setContinueHandler(() {
      _stateController.add(TtsState.playing);
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      final segIdx = _findSegmentForOffset(start);
      if (segIdx != _currentSegmentIndex && segIdx >= 0) {
        _currentSegmentIndex = segIdx;
        _sentenceController.add(segIdx);
      }
    });

    _tts.setErrorHandler((dynamic msg) {
      _stateController.add(TtsState.error);
    });
  }

  int _findSegmentForOffset(int offset) {
    for (var i = 0; i < _segments.length; i++) {
      if (offset >= _segments[i].startOffset && offset < _segments[i].endOffset) {
        return i;
      }
    }
    return -1;
  }

  @override
  Future<void> speak(String text) async {
    _segments = TtsSentenceSegmenter.segment(text);
    _currentSegmentIndex = 0;
    await _applySettings();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _stateController.add(TtsState.stopped);
  }

  @override
  Future<void> pause() async {
    await _tts.pause();
    _stateController.add(TtsState.paused);
  }

  @override
  Future<void> resume() async {
    await _tts.awaitSpeakCompletion(true);
    _stateController.add(TtsState.playing);
  }

  @override
  Future<void> previous() async {
    if (_currentSegmentIndex > 0) {
      _currentSegmentIndex--;
      _sentenceController.add(_currentSegmentIndex);
      final text = _segments.map((s) => s.text).join(' ');
      await speak(text);
    }
  }

  @override
  Future<void> next() async {
    if (_currentSegmentIndex < _segments.length - 1) {
      _currentSegmentIndex++;
      _sentenceController.add(_currentSegmentIndex);
      final text = _segments.map((s) => s.text).join(' ');
      await speak(text);
    }
  }

  @override
  Future<List<TtsVoice>> voices() async {
    final raw = await _tts.getVoices;
    return (raw as List).map((v) {
      final map = v as Map<dynamic, dynamic>;
      return TtsVoice(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        language: map['locale']?.toString() ?? '',
        gender: map['gender']?.toString(),
      );
    }).toList();
  }

  @override
  Future<void> setVolume(double volume) async {
    _settings = _settings.copyWith(volume: volume);
    await _tts.setVolume(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    _settings = _settings.copyWith(rate: rate);
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    _settings = _settings.copyWith(pitch: pitch);
    await _tts.setPitch(pitch);
  }

  @override
  Future<void> setVoice(TtsVoice voice) async {
    _settings = _settings.copyWith(voiceId: voice.id);
    await _tts.setVoice({'id': voice.id, 'name': voice.name});
  }

  Future<void> applySettings(TtsSettings settings) async {
    _settings = settings;
    await _applySettings();
  }

  Future<void> _applySettings() async {
    await _tts.setVolume(_settings.volume);
    await _tts.setSpeechRate(_settings.rate);
    await _tts.setPitch(_settings.pitch);
    if (_settings.voiceId != null) {
      await _tts.setVoice({'id': _settings.voiceId!, 'name': ''});
    }
  }

  TtsSettings get settings => _settings;

  @override
  void dispose() {
    unawaited(_tts.stop());
    unawaited(_stateController.close());
    unawaited(_sentenceController.close());
  }
}

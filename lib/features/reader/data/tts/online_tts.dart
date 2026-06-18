import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'base_tts.dart';

enum OnlineTtsProvider { openai, azure, aliyun }

class OnlineTtsConfig {
  const OnlineTtsConfig({
    required this.provider,
    required this.apiKey,
    this.endpoint,
    this.model = 'tts-1',
    this.voice = 'alloy',
  });

  final OnlineTtsProvider provider;
  final String apiKey;
  final String? endpoint;
  final String model;
  final String voice;

  Map<String, dynamic> toJson() => {
    'provider': provider.index,
    'apiKey': apiKey,
    'endpoint': endpoint,
    'model': model,
    'voice': voice,
  };

  factory OnlineTtsConfig.fromJson(Map<String, dynamic> json) => OnlineTtsConfig(
    provider: OnlineTtsProvider.values[json['provider'] as int? ?? 0],
    apiKey: json['apiKey'] as String,
    endpoint: json['endpoint'] as String?,
    model: json['model'] as String? ?? 'tts-1',
    voice: json['voice'] as String? ?? 'alloy',
  );
}

class OnlineTtsProviderImpl extends BaseTts {
  OnlineTtsProviderImpl(this._dio, this._config);

  final Dio _dio;
  final OnlineTtsConfig _config;

  final _stateController = StreamController<TtsState>.broadcast();
  final _sentenceController = StreamController<int>.broadcast();

  List<TtsSegment> _segments = [];
  int _currentSegmentIndex = 0;

  @override
  Stream<TtsState> get onStateChange => _stateController.stream;

  @override
  Stream<int> get onSentenceIndex => _sentenceController.stream;

  @override
  Future<void> speak(String text) async {
    _segments = TtsSentenceSegmenter.segment(text);
    _currentSegmentIndex = 0;
    _stateController.add(TtsState.playing);

    try {
      for (var i = 0; i < _segments.length; i++) {
        if (_currentSegmentIndex != i) break;

        _sentenceController.add(i);
        await _synthesizeSegment(_segments[i].text);
      }
      _stateController.add(TtsState.stopped);
    } on Object catch (_) {
      _stateController.add(TtsState.error);
    }
  }

  Future<void> _synthesizeSegment(String text) async {
    final endpoint = _config.endpoint ?? _getDefaultEndpoint();
    await _dio.post<dynamic>(
      endpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_config.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      data: jsonEncode({
        'model': _config.model,
        'input': text,
        'voice': _config.voice,
        'response_format': 'mp3',
      }),
    );

    // In a real implementation, play the audio bytes
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  String _getDefaultEndpoint() {
    switch (_config.provider) {
      case OnlineTtsProvider.openai:
        return 'https://api.openai.com/v1/audio/speech';
      case OnlineTtsProvider.azure:
        return '${_config.endpoint}/cognitiveservices/v1';
      case OnlineTtsProvider.aliyun:
        return 'https://nls-gateway.cn-shanghai.aliyuncs.com/v1/tts/convert';
    }
  }

  @override
  Future<void> stop() async {
    _currentSegmentIndex = -1;
    _stateController.add(TtsState.stopped);
  }

  @override
  Future<void> pause() async {
    _stateController.add(TtsState.paused);
  }

  @override
  Future<void> resume() async {
    _stateController.add(TtsState.playing);
  }

  @override
  Future<void> previous() async {
    if (_currentSegmentIndex > 0) {
      _currentSegmentIndex--;
      _sentenceController.add(_currentSegmentIndex);
    }
  }

  @override
  Future<void> next() async {
    if (_currentSegmentIndex < _segments.length - 1) {
      _currentSegmentIndex++;
      _sentenceController.add(_currentSegmentIndex);
    }
  }

  @override
  Future<List<TtsVoice>> voices() async {
    return const [
      TtsVoice(id: 'alloy', name: 'Alloy', language: 'en-US'),
      TtsVoice(id: 'echo', name: 'Echo', language: 'en-US'),
      TtsVoice(id: 'fable', name: 'Fable', language: 'en-US'),
      TtsVoice(id: 'onyx', name: 'Onyx', language: 'en-US'),
      TtsVoice(id: 'nova', name: 'Nova', language: 'en-US'),
      TtsVoice(id: 'shimmer', name: 'Shimmer', language: 'en-US'),
    ];
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setVoice(TtsVoice voice) async {}

  @override
  void dispose() {
    unawaited(_stateController.close());
    unawaited(_sentenceController.close());
  }
}

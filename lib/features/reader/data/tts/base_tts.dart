import 'dart:async';

abstract class BaseTts {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> previous();
  Future<void> next();
  Future<List<TtsVoice>> voices();

  Stream<TtsState> get onStateChange;
  Stream<int> get onSentenceIndex;

  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVoice(TtsVoice voice);

  void dispose();
}

enum TtsState { playing, paused, stopped, error }

class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.name,
    required this.language,
    this.gender,
  });

  final String id;
  final String name;
  final String language;
  final String? gender;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'language': language,
    'gender': gender,
  };

  factory TtsVoice.fromJson(Map<String, dynamic> json) => TtsVoice(
    id: json['id'] as String,
    name: json['name'] as String,
    language: json['language'] as String,
    gender: json['gender'] as String?,
  );
}

class TtsSettings {
  const TtsSettings({
    this.volume = 1.0,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.voiceId,
    this.language = 'ru-RU',
  });

  final double volume;
  final double rate;
  final double pitch;
  final String? voiceId;
  final String language;

  TtsSettings copyWith({
    double? volume,
    double? rate,
    double? pitch,
    String? voiceId,
    String? language,
  }) {
    return TtsSettings(
      volume: volume ?? this.volume,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      voiceId: voiceId ?? this.voiceId,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'volume': volume,
    'rate': rate,
    'pitch': pitch,
    'voiceId': voiceId,
    'language': language,
  };

  factory TtsSettings.fromJson(Map<String, dynamic> json) => TtsSettings(
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    rate: (json['rate'] as num?)?.toDouble() ?? 0.5,
    pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
    voiceId: json['voiceId'] as String?,
    language: json['language'] as String? ?? 'ru-RU',
  );
}

class TtsSegment {
  const TtsSegment({
    required this.text,
    required this.index,
    this.startOffset = 0,
    this.endOffset = 0,
  });

  final String text;
  final int index;
  final int startOffset;
  final int endOffset;
}

class TtsSentenceSegmenter {
  static List<TtsSegment> segment(String text) {
    final segments = <TtsSegment>[];
    final pattern = RegExp(r'(?<=[.!?…])\s+');
    final sentences = text.split(pattern);

    var offset = 0;
    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;
      segments.add(
        TtsSegment(
          text: sentence,
          index: i,
          startOffset: offset,
          endOffset: offset + sentence.length,
        ),
      );
      offset += sentence.length + 1;
    }

    return segments;
  }
}

class TtsSleepTimer {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _active = false;

  bool get isActive => _active;
  int get remainingSeconds => _remainingSeconds;

  final _stateController = StreamController<TtsSleepState>.broadcast();
  Stream<TtsSleepState> get onStateChange => _stateController.stream;

  void start(int minutes, {VoidCallback? onExpire}) {
    stop();
    _remainingSeconds = minutes * 60;
    _active = true;
    _stateController.add(TtsSleepState(active: true, remainingSeconds: _remainingSeconds));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      _stateController.add(TtsSleepState(active: true, remainingSeconds: _remainingSeconds));

      if (_remainingSeconds <= 0) {
        stop();
        onExpire?.call();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _active = false;
    _remainingSeconds = 0;
    _stateController.add(const TtsSleepState(active: false, remainingSeconds: 0));
  }

  void dispose() {
    _timer?.cancel();
    _stateController.close();
  }
}

class TtsSleepState {
  const TtsSleepState({required this.active, required this.remainingSeconds});

  final bool active;
  final int remainingSeconds;

  String get display {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

typedef VoidCallback = void Function();

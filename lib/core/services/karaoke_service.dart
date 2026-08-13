import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/reader/data/parsers/smil_parser.dart';

/// LW-6.1: Karaoke service — synchronizes text highlighting with audio playback.
/// Uses SMIL timing data from EPUB3 Media Overlays.
class KaraokeService {
  KaraokeService._();
  static final KaraokeService instance = KaraokeService._();

  final AudioPlayer _player = AudioPlayer();
  List<SmilEntry> _entries = [];
  StreamSubscription<Duration>? _positionSub;

  // Current active paragraph index
  final _activeParagraphController = StreamController<int>.broadcast();
  Stream<int> get activeParagraph => _activeParagraphController.stream;

  int _currentEntryIndex = -1;

  /// Load SMIL entries and audio file.
  Future<bool> load({
    required List<SmilEntry> entries,
    required String audioPath,
  }) async {
    await stop();
    _entries = entries;

    try {
      await _player.setFilePath(audioPath);

      _positionSub = _player.positionStream.listen(_onPositionChanged);
      return true;
    } on Object catch (e) {
      _entries = [];
      debugPrint('Karaoke load failed: $e');
      return false;
    }
  }

  void _onPositionChanged(Duration position) {
    if (_entries.isEmpty) return;

    // Find which entry the current position falls in
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (position >= entry.clipBegin && position < entry.clipEnd) {
        if (i != _currentEntryIndex) {
          _currentEntryIndex = i;
          _activeParagraphController.add(i);
        }
        return;
      }
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> rewind() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    _currentEntryIndex = -1;
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    await _player.stop();
    _currentEntryIndex = -1;
    _entries = [];
  }

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;

  void dispose() {
    _positionSub?.cancel(); // ignore: discarded_futures
    _player.dispose(); // ignore: discarded_futures
    _activeParagraphController.close(); // ignore: discarded_futures
  }
}

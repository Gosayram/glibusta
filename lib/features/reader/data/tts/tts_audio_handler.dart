import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TtsAudioHandler extends BaseAudioHandler with SeekHandler {
  TtsAudioHandler() {
    _init();
  }

  void _init() {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
      ),
    );
  }

  Future<void> playTts(String title, String author, {Duration? duration}) async {
    mediaItem.add(
      MediaItem(
        id: 'tts_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        artist: author,
        duration: duration,
      ),
    );

    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: true,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
      ),
    );
  }

  void updateProgress({required bool isPlaying, required bool isPaused}) {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
        playing: isPlaying,
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
      ),
    );
  }

  Future<void> notifyStopped() async {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
        controls: const [],
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    final duration = mediaItem.value?.duration;
    if (duration == null || duration.inMilliseconds <= 0) return;

    final clamped = position.isNegative
        ? Duration.zero
        : position > duration
            ? duration
            : position;

    playbackState.add(
      playbackState.value.copyWith(updatePosition: clamped),
    );
  }

  @override
  Future<void> stop() async {
    await playbackState.firstWhere(
      (state) => state.processingState == AudioProcessingState.idle,
      orElse: () => playbackState.value,
    );
    await super.stop();
  }
}

class TtsAudioService {
  TtsAudioHandler? _handler;

  Future<TtsAudioHandler> getHandler() async {
    if (_handler != null) return _handler!;

    _handler = await AudioService.init(
      builder: () => TtsAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.glibusta.tts',
        androidNotificationChannelName: 'TTS Reading',
        androidNotificationOngoing: true,
      ),
    );

    return _handler!;
  }

  Future<void> play(String title, String author, {Duration? duration}) async {
    final handler = await getHandler();
    await handler.playTts(title, author, duration: duration);
  }

  void updateProgress({required bool isPlaying, required bool isPaused}) {
    _handler?.updateProgress(isPlaying: isPlaying, isPaused: isPaused);
  }

  Future<void> stop() async {
    await _handler?.notifyStopped();
  }

  void dispose() {
    _handler = null;
  }
}

final ttsAudioServiceProvider = Provider<TtsAudioService>((ref) => TtsAudioService());

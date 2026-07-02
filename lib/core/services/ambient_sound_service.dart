import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// LW-4.1-4.3: Background ambient sounds service.
/// ponytail: procedurally generated noise (brown/pink), no bundled assets needed.
/// Works offline, no network, no external files.
class AmbientSoundService {
  AmbientSoundService._();
  static final AmbientSoundService instance = AmbientSoundService._();

  final Map<AmbientType, AudioPlayer> _players = {};
  final Map<AmbientType, double> _volumes = {};

  /// Start playing an ambient sound.
  Future<void> play(AmbientType type, {double volume = 0.3}) async {
    if (_players.containsKey(type)) {
      await setVolume(type, volume);
      return;
    }
    try {
      final player = AudioPlayer();
      final waveData = _generateNoise(type);
      // Write WAV to temp file (just_audio needs file or URL)
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ambient_${type.name}.wav');
      await file.writeAsBytes(waveData, flush: true);
      await player.setFilePath(file.path);
      await player.setVolume(volume * 100);
      await player.setLoopMode(LoopMode.one);
      await player.play();
      _players[type] = player;
      _volumes[type] = volume;
    } on Object catch (e) {
      debugPrint('Ambient sound failed for ${type.name}: $e');
    }
  }

  /// Stop a specific sound.
  Future<void> stop(AmbientType type) async {
    final player = _players.remove(type);
    _volumes.remove(type);
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
  }

  /// Stop all sounds.
  Future<void> stopAll() async {
    for (final type in _players.keys.toList()) {
      await stop(type);
    }
  }

  /// Set volume for a specific sound (0.0 – 1.0).
  Future<void> setVolume(AmbientType type, double volume) async {
    final player = _players[type];
    if (player != null) {
      await player.setVolume(volume * 100);
      _volumes[type] = volume;
    }
  }

  bool isPlaying(AmbientType type) => _players.containsKey(type);
  double getVolume(AmbientType type) => _volumes[type] ?? 0;

  /// Generate a WAV file (PCM 16-bit mono 22050Hz) with procedural noise.
  Uint8List _generateNoise(AmbientType type, {int durationSeconds = 10}) {
    const sampleRate = 22050;
    const channels = 1;
    const bitsPerSample = 16;
    final totalSamples = sampleRate * durationSeconds;
    final dataBytes = totalSamples * 2; // 16-bit = 2 bytes per sample

    final pcm = Int16List(totalSamples);
    final rng = Random(type.index);

    switch (type) {
      case AmbientType.rain:
        _generateBrownNoise(pcm, rng, sampleRate);
      case AmbientType.fire:
        _generatePinkNoise(pcm, rng);
      case AmbientType.wind:
        _generateWindNoise(pcm, rng, sampleRate);
      case AmbientType.forest:
        _generateForestNoise(pcm, rng, sampleRate);
      case AmbientType.cafe:
        _generateCafeNoise(pcm, rng, sampleRate);
    }

    // Build WAV file
    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataBytes, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt subchunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little); // subchunk1 size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data subchunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataBytes, Endian.little);

    final result = Uint8List(44 + dataBytes);
    result.setAll(0, header.buffer.asUint8List());
    // Write PCM samples as little-endian 16-bit
    final byteData = ByteData(dataBytes);
    for (var i = 0; i < totalSamples; i++) {
      byteData.setInt16(i * 2, pcm[i].clamp(-32768, 32767), Endian.little);
    }
    result.setAll(44, byteData.buffer.asUint8List());
    return result;
  }

  /// Brown noise: accumulated random walk — deep, rumbling (rain).
  void _generateBrownNoise(Int16List pcm, Random rng, int sampleRate) {
    var last = 0.0;
    final decay = exp(-1.0 / (sampleRate * 0.01)); // time constant
    for (var i = 0; i < pcm.length; i++) {
      last = last * decay + (rng.nextDouble() * 2 - 1) * (1 - decay) * 0.5;
      pcm[i] = (last * 32000).round().clamp(-32768, 32767);
    }
  }

  /// Pink noise: 1/f spectrum — warm, natural (fire).
  void _generatePinkNoise(Int16List pcm, Random rng) {
    var b0 = 0.0;
    var b1 = 0.0;
    var b2 = 0.0;
    var b3 = 0.0;
    var b4 = 0.0;
    var b5 = 0.0;
    var b6 = 0.0;
    for (var i = 0; i < pcm.length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      final pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
      b6 = white * 0.115926;
      pcm[i] = (pink * 32000).round().clamp(-32768, 32767);
    }
  }

  /// Wind noise: filtered noise with slow modulation.
  void _generateWindNoise(Int16List pcm, Random rng, int sampleRate) {
    var last = 0.0;
    final modFreq = 0.3; // slow modulation
    for (var i = 0; i < pcm.length; i++) {
      final t = i / sampleRate;
      final modulator = (sin(2 * pi * modFreq * t) + 1) * 0.5; // 0..1
      final raw = (rng.nextDouble() * 2 - 1) * modulator;
      last = last * 0.97 + raw * 0.03;
      pcm[i] = (last * 28000).round().clamp(-32768, 32767);
    }
  }

  /// Forest: layered bird-like chirps on a bed of pink noise.
  void _generateForestNoise(Int16List pcm, Random rng, int sampleRate) {
    _generatePinkNoise(pcm, rng);
    // Overlay chirps at random intervals
    final chirpInterval = sampleRate * 2; // chirp every ~2s
    for (var i = 0; i < pcm.length; i++) {
      final phase = i % chirpInterval;
      if (phase < sampleRate * 0.15) {
        // Chirp: short sine burst at 2000-4000Hz
        final freq = 2000.0 + rng.nextDouble() * 2000;
        final t = phase / sampleRate;
        final envelope = sin(pi * t / 0.15); // bell shape
        final chirp = sin(2 * pi * freq * t) * envelope * 8000;
        pcm[i] = (pcm[i] + chirp.round()).clamp(-32768, 32767);
      }
    }
  }

  /// Cafe: low hum with occasional clinks.
  void _generateCafeNoise(Int16List pcm, Random rng, int sampleRate) {
    _generateBrownNoise(pcm, rng, sampleRate);
    // Overlay clinking sounds
    final clinkInterval = sampleRate * 4; // clink every ~4s
    for (var i = 0; i < pcm.length; i++) {
      final phase = i % clinkInterval;
      if (phase < sampleRate * 0.05) {
        final freq = 5000.0 + rng.nextDouble() * 3000;
        final t = phase / sampleRate;
        final envelope = exp(-t * 60); // sharp decay
        final clink = sin(2 * pi * freq * t) * envelope * 12000;
        pcm[i] = (pcm[i] + clink.round()).clamp(-32768, 32767);
      }
    }
  }
}

enum AmbientType { rain, fire, wind, forest, cafe }

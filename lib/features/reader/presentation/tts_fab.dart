import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts/base_tts.dart';
import '../data/tts/tts_service.dart';

class TtsFab extends ConsumerStatefulWidget {
  const TtsFab({required this.text, super.key});

  final String text;

  @override
  ConsumerState<TtsFab> createState() => _TtsFabState();
}

class _TtsFabState extends ConsumerState<TtsFab> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ttsService = ref.read(ttsServiceProvider);
    final ttsState = ref.watch(ttsStateProvider);
    final sleepTimer = ref.read(ttsSleepTimerProvider);
    final isPlaying = ttsState == TtsState.playing;
    final isPaused = ttsState == TtsState.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          _buildExpandedPanel(context, ttsService, sleepTimer),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaying || isPaused)
              FloatingActionButton.small(
                heroTag: 'tts_expand',
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Icon(_expanded ? Icons.keyboard_arrow_down : Icons.tune),
              ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'tts_main',
              onPressed: () => _toggleTts(ttsService),
              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            if (isPlaying || isPaused) ...[
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'tts_stop',
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                onPressed: () {
                  unawaited(ttsService.stop());
                  ref.read(ttsStateProvider.notifier).update(TtsState.stopped);
                },
                child: Icon(
                  Icons.stop,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _toggleTts(TtsService ttsService) async {
    final current = ref.read(ttsStateProvider);
    if (current == TtsState.playing) {
      await ttsService.pause();
      ref.read(ttsStateProvider.notifier).update(TtsState.paused);
    } else if (current == TtsState.paused) {
      await ttsService.resume();
      ref.read(ttsStateProvider.notifier).update(TtsState.playing);
    } else {
      await ttsService.speak(widget.text);
      ref.read(ttsStateProvider.notifier).update(TtsState.playing);
    }
  }

  Widget _buildExpandedPanel(
    BuildContext context,
    TtsService ttsService,
    TtsSleepTimer sleepTimer,
  ) {
    final theme = Theme.of(context);
    final settings = ttsService.settings;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Настройки озвучки', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _buildSlider(
              label: 'Громкость',
              value: settings.volume,
              min: 0,
              max: 1,
              onChanged: (v) => ttsService.updateSettings(settings.copyWith(volume: v)),
            ),
            _buildSlider(
              label: 'Скорость',
              value: settings.rate,
              min: 0.1,
              max: 1.5,
              onChanged: (v) => ttsService.updateSettings(settings.copyWith(rate: v)),
            ),
            _buildSlider(
              label: 'Тон',
              value: settings.pitch,
              min: 0.5,
              max: 2.0,
              onChanged: (v) => ttsService.updateSettings(settings.copyWith(pitch: v)),
            ),
            const Divider(height: 24),
            Text('Таймер сна', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildSleepChip('5 мин', 5, sleepTimer),
                _buildSleepChip('15 мин', 15, sleepTimer),
                _buildSleepChip('30 мин', 30, sleepTimer),
                _buildSleepChip('60 мин', 60, sleepTimer),
                if (sleepTimer.isActive)
                  ActionChip(
                    label: Text('Стоп (${sleepTimer.remainingSeconds ~/ 60}м)'),
                    onPressed: sleepTimer.stop,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepChip(String label, int minutes, TtsSleepTimer sleepTimer) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        final ttsService = ref.read(ttsServiceProvider);
        final ttsStateNotifier = ref.read(ttsStateProvider.notifier);
        sleepTimer.start(
          minutes,
          onExpire: () {
            if (!mounted) return;
            unawaited(ttsService.stop());
            ttsStateNotifier.update(TtsState.stopped);
          },
        );
      },
    );
  }
}

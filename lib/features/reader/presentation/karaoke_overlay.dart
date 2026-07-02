import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/parsers/smil_parser.dart';

/// LW-6.1: Karaoke overlay — auto-advances through SMIL entries via timer.
/// ponytail: timer-based, no audio playback. Audio requires EPUB audio extraction.
class KaraokeOverlay extends StatefulWidget {
  const KaraokeOverlay({
    super.key,
    required this.entries,
    required this.chapterBlocks,
  });

  final List<SmilEntry> entries;
  final List<String> chapterBlocks;

  @override
  State<KaraokeOverlay> createState() => _KaraokeOverlayState();
}

class _KaraokeOverlayState extends State<KaraokeOverlay> {
  Timer? _timer;
  var _currentIndex = 0;
  var _isPlaying = false;
  var _elapsed = Duration.zero;
  var _startTime = DateTime.now();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      _startTime = DateTime.now().subtract(_elapsed);
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
      setState(() => _isPlaying = true);
    }
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final elapsed = now.difference(_startTime);
    setState(() => _elapsed = elapsed);

    // Find current entry by elapsed time
    for (var i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      if (elapsed >= entry.clipBegin && elapsed < entry.clipEnd) {
        if (i != _currentIndex) _currentIndex = i;
        return;
      }
    }
    // Past the end
    if (elapsed > widget.entries.last.clipEnd) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
    }
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentIndex = 0;
      _elapsed = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = widget.entries;
    final current = _currentIndex < entries.length ? entries[_currentIndex] : null;
    final totalMs = entries.fold<int>(0, (s, e) => s + (e.clipEnd - e.clipBegin).inMilliseconds);
    final progressMs = _elapsed.inMilliseconds.clamp(0, totalMs);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.music_note, size: 20),
          const SizedBox(width: 8),
          const Text('Karaoke', style: TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            '${_currentIndex + 1}/${entries.length}',
            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalMs > 0 ? progressMs / totalMs : 0,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            // Current paragraph text
            if (current != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _currentParagraphText(current),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${current.clipBegin.inSeconds}s — ${current.clipEnd.inSeconds}s',
                style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ],
            const SizedBox(height: 16),
            // Entry list (compact)
            SizedBox(
              height: min(200, entries.length * 28.0),
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final isActive = i == _currentIndex;
                  final blockText = _blockTextForEntry(e);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? colors.primary.withValues(alpha: 0.12) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            blockText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              color: isActive ? colors.primary : colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 18),
          label: Text(_isPlaying ? 'Пауза' : 'Старт'),
          onPressed: _togglePlay,
        ),
        TextButton.icon(
          icon: const Icon(Icons.stop, size: 18),
          label: const Text('Стоп'),
          onPressed: _stop,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  String _currentParagraphText(SmilEntry entry) {
    return _blockTextForEntry(entry);
  }

  String _blockTextForEntry(SmilEntry entry) {
    final idx = widget.chapterBlocks.indexWhere((String b) {
      // Match by textRef — strip fragment (e.g. "xhtml/ch1.xhtml#p1" → look for id="p1")
      final ref = entry.textRef;
      final fragment = ref.contains('#') ? ref.split('#').last : ref;
      return b.contains(fragment as Pattern) || b.contains(ref as Pattern);
    });
    if (idx < 0) {
      // Fall back to clipBegin ordering: just show the entry index
      final i = widget.entries.indexOf(entry);
      return i < widget.chapterBlocks.length ? widget.chapterBlocks[i] : 'Paragraph ${i + 1}';
    }
    return widget.chapterBlocks[idx];
  }
}

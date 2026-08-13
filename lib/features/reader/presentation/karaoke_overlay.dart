import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/services/karaoke_service.dart';
import '../data/parsers/smil_parser.dart';

/// LW-6.1: Karaoke overlay — synchronizes text highlighting with EPUB audio.
class KaraokeOverlay extends StatefulWidget {
  const KaraokeOverlay({
    super.key,
    required this.entries,
    required this.chapterBlocks,
    required this.audioPath,
  });

  final List<SmilEntry> entries;
  final List<String> chapterBlocks;
  final String audioPath;

  @override
  State<KaraokeOverlay> createState() => _KaraokeOverlayState();
}

class _KaraokeOverlayState extends State<KaraokeOverlay> {
  final KaraokeService _karaokeService = KaraokeService.instance;
  StreamSubscription<int>? _activeParagraphSub;
  StreamSubscription<Duration>? _positionSub;
  var _currentIndex = 0;
  var _isPlaying = false;
  var _position = Duration.zero;
  var _isPreparing = true;
  var _audioAvailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareAudio());
  }

  @override
  void dispose() {
    unawaited(_activeParagraphSub?.cancel());
    unawaited(_positionSub?.cancel());
    unawaited(_karaokeService.stop());
    super.dispose();
  }

  Future<void> _prepareAudio() async {
    final loaded = await _karaokeService.load(entries: widget.entries, audioPath: widget.audioPath);
    if (!mounted) return;
    if (loaded) {
      _activeParagraphSub = _karaokeService.activeParagraph.listen((index) {
        if (mounted) setState(() => _currentIndex = index);
      });
      _positionSub = _karaokeService.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      });
    }
    setState(() {
      _isPreparing = false;
      _audioAvailable = loaded;
    });
  }

  Future<void> _togglePlay() async {
    if (!_audioAvailable) return;
    if (_karaokeService.isPlaying) {
      await _karaokeService.pause();
    } else {
      await _karaokeService.play();
    }
    if (mounted) setState(() => _isPlaying = _karaokeService.isPlaying);
  }

  Future<void> _stop() async {
    await _karaokeService.rewind();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentIndex = 0;
        _position = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = widget.entries;
    final current = _currentIndex < entries.length ? entries[_currentIndex] : null;
    final total = entries.fold<Duration>(
      Duration.zero,
      (latest, entry) => entry.clipEnd > latest ? entry.clipEnd : latest,
    );
    final totalMs = total.inMilliseconds;
    final progressMs = _position.inMilliseconds.clamp(0, totalMs);

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
            if (_isPreparing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              )
            else if (!_audioAvailable)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Аудиодорожка недоступна для воспроизведения.'),
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
          onPressed: _audioAvailable ? _togglePlay : null,
        ),
        TextButton.icon(
          icon: const Icon(Icons.stop, size: 18),
          label: const Text('Стоп'),
          onPressed: _audioAvailable ? _stop : null,
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

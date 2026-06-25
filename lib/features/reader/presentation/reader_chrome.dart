import 'package:flutter/material.dart';

import '../data/reader_colors.dart';
import '../domain/reader.dart';

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.settings,
    required this.bookTitle,
    required this.onBack,
    this.onSearch,
    this.onMore,
  });

  final ReaderSettings settings;
  final String bookTitle;
  final VoidCallback onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.scaffold.withValues(alpha: 0.95),
              colors.scaffold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: colors.text,
              tooltip: 'Назад',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                bookTitle,
                style: TextStyle(color: colors.text, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                semanticsLabel: 'Книга: $bookTitle',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              color: colors.text,
              tooltip: 'Поиск по книге',
              onPressed: onSearch ?? () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              color: colors.text,
              tooltip: 'Настройки',
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.settings,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.scrollProgress,
    required this.estimatedMinutesLeft,
    required this.chapterTitle,
    this.onJumpToProgress,
    this.onModeChanged,
    this.checkpoints = const [],
    this.onCheckpointForward,
    this.onCheckpointBack,
  });

  final ReaderSettings settings;
  final int currentChapterIndex;
  final int totalChapters;
  final double scrollProgress;
  final int estimatedMinutesLeft;
  final String chapterTitle;
  final ValueChanged<double>? onJumpToProgress;
  final ValueChanged<ReaderMode>? onModeChanged;
  final List<double> checkpoints;
  final VoidCallback? onCheckpointForward;
  final VoidCallback? onCheckpointBack;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    if (settings.bottomBarContent == BottomBarContent.none) {
      return const SizedBox.shrink();
    }

    final percent = (scrollProgress * 100).round();
    final page = (scrollProgress * totalChapters).ceil().clamp(1, totalChapters);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              colors.scaffold.withValues(alpha: 0.95),
              colors.scaffold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chapter title
            if (chapterTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  chapterTitle,
                  style: TextStyle(
                    color: colors.text.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Progress info — respects bottomBarContent setting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _leftLabel(settings, page, totalChapters, percent),
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
                Text(
                  _rightLabel(settings, page, totalChapters, percent, estimatedMinutesLeft),
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
              ],
            ),
            // Slider
            if (onJumpToProgress != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (onCheckpointBack != null)
                    GestureDetector(
                      onTap: onCheckpointBack,
                      child: Icon(
                        Icons.bookmark,
                        size: 16,
                        color: checkpoints.any((c) => c < scrollProgress - 0.02)
                            ? colors.text.withValues(alpha: 0.6)
                            : colors.text.withValues(alpha: 0.15),
                      ),
                    ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colors.text.withValues(alpha: 0.4),
                        inactiveTrackColor: colors.text.withValues(alpha: 0.15),
                        thumbColor: colors.text.withValues(alpha: 0.7),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 2,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: scrollProgress.clamp(0.0, 1.0),
                        onChanged: onJumpToProgress,
                      ),
                    ),
                  ),
                  if (onCheckpointForward != null)
                    GestureDetector(
                      onTap: onCheckpointForward,
                      child: Icon(
                        Icons.bookmark,
                        size: 16,
                        color: checkpoints.any((c) => c > scrollProgress + 0.02)
                            ? colors.text.withValues(alpha: 0.6)
                            : colors.text.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ),
              // Checkpoint markers
              if (checkpoints.isNotEmpty)
                SizedBox(
                  height: 6,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _CheckpointMarkerPainter(
                      checkpoints: checkpoints,
                      color: colors.text,
                    ),
                  ),
                ),
            ],
            // Mode switcher
            if (onModeChanged != null) _buildModeSwitcher(colors),
          ],
        ),
      ),
    );
  }

  String _leftLabel(ReaderSettings settings, int page, int totalChapters, int percent) {
    switch (settings.bottomBarContent) {
      case BottomBarContent.page:
        return '$page / $totalChapters';
      case BottomBarContent.percent:
        return '$percent%';
      case BottomBarContent.chapter:
        return '$page / $totalChapters';
      case BottomBarContent.time:
        return '$page / $totalChapters';
      case BottomBarContent.none:
        return '';
    }
  }

  String _rightLabel(ReaderSettings settings, int page, int totalChapters, int percent, int minutesLeft) {
    switch (settings.bottomBarContent) {
      case BottomBarContent.page:
        return '$percent%';
      case BottomBarContent.percent:
        return '$page / $totalChapters';
      case BottomBarContent.chapter:
        return '$percent%';
      case BottomBarContent.time:
        return minutesLeft > 0 ? '~$minutesLeft мин' : '$percent%';
      case BottomBarContent.none:
        return '';
    }
  }

  Widget _buildModeSwitcher(ReaderColors colors) {
    const modes = <ReaderMode, String>{
      ReaderMode.paginated: 'Страницы',
      ReaderMode.continuous: 'Прокрутка',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: modes.entries.map((entry) {
        final isSelected = settings.mode == entry.key;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => onModeChanged?.call(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.text.withValues(alpha: 0.15)
                    : colors.text.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? colors.text.withValues(alpha: 0.3)
                      : colors.text.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? colors.text : colors.text.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ReaderProgressBar extends StatelessWidget {
  const ReaderProgressBar({
    super.key,
    required this.scrollProgress,
    required this.theme,
  });

  final double scrollProgress;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: LinearProgressIndicator(
          value: scrollProgress,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            ReaderColors.progressColor(theme),
          ),
        ),
      ),
    );
  }
}

class _CheckpointMarkerPainter extends CustomPainter {
  _CheckpointMarkerPainter({
    required this.checkpoints,
    required this.color,
  });

  final List<double> checkpoints;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final cp in checkpoints) {
      final x = cp.clamp(0.0, 1.0) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckpointMarkerPainter oldDelegate) =>
      checkpoints != oldDelegate.checkpoints;
}

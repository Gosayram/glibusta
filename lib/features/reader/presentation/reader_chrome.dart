import 'package:flutter/material.dart';

import '../data/reader_colors.dart';
import '../domain/reader.dart';

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.settings,
    required this.bookTitle,
    required this.onBack,
    required this.onSettings,
  });

  final ReaderSettings settings;
  final String bookTitle;
  final VoidCallback onBack;
  final VoidCallback onSettings;

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
              icon: Icon(Icons.arrow_back, color: colors.text),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                bookTitle,
                style: TextStyle(color: colors.text, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: colors.text),
              tooltip: 'Настройки чтения',
              onPressed: onSettings,
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
    this.onJumpToProgress,
  });

  final ReaderSettings settings;
  final int currentChapterIndex;
  final int totalChapters;
  final double scrollProgress;
  final int estimatedMinutesLeft;
  final ValueChanged<double>? onJumpToProgress;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    if (settings.bottomBarContent == BottomBarContent.none) {
      return const SizedBox.shrink();
    }

    final leftText = _buildLeftText(settings.bottomBarContent);
    final rightText = _buildRightText(settings.bottomBarContent);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(leftText, style: TextStyle(color: colors.text, fontSize: 12)),
                Text(rightText, style: TextStyle(color: colors.text, fontSize: 12)),
              ],
            ),
            if (onJumpToProgress != null) ...[
              const SizedBox(height: 4),
              SliderTheme(
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
            ],
          ],
        ),
      ),
    );
  }

  String _buildLeftText(BottomBarContent content) {
    switch (content) {
      case BottomBarContent.percent:
        return '${(scrollProgress * 100).round()}%';
      case BottomBarContent.page:
        final page = (scrollProgress * totalChapters).ceil();
        return 'Стр. $page';
      case BottomBarContent.chapter:
        return 'Глава ${currentChapterIndex + 1} из $totalChapters';
      case BottomBarContent.time:
        final remainingMinutes = (estimatedMinutesLeft * (1 - scrollProgress)).round();
        final hours = remainingMinutes ~/ 60;
        final mins = remainingMinutes % 60;
        return hours > 0 ? '~${hours}ч ${mins}м' : '~${mins}м';
      case BottomBarContent.none:
        return '';
    }
  }

  String _buildRightText(BottomBarContent content) {
    switch (content) {
      case BottomBarContent.percent:
        final remainingMinutes = (estimatedMinutesLeft * (1 - scrollProgress)).round();
        final hours = remainingMinutes ~/ 60;
        final mins = remainingMinutes % 60;
        return hours > 0 ? '~${hours}ч ${mins}м' : '~${mins}м';
      case BottomBarContent.page:
        return 'Глава ${currentChapterIndex + 1} из $totalChapters';
      case BottomBarContent.chapter:
        return '${(scrollProgress * 100).round()}%';
      case BottomBarContent.time:
        return '${(scrollProgress * 100).round()}%';
      case BottomBarContent.none:
        return '';
    }
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

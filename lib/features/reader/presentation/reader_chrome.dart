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
  });

  final ReaderSettings settings;
  final int currentChapterIndex;
  final int totalChapters;
  final double scrollProgress;
  final int estimatedMinutesLeft;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    final percentage = (scrollProgress * 100).round();
    final remainingMinutes = (estimatedMinutesLeft * (1 - scrollProgress)).round();
    final hours = remainingMinutes ~/ 60;
    final mins = remainingMinutes % 60;
    // ignore: unnecessary_brace_in_string_interps — braces needed before Cyrillic chars
    final timeStr = hours > 0 ? '~${hours}ч ${mins}м' : '~${mins}м';

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
                Text(
                  'Глава ${currentChapterIndex + 1} из $totalChapters',
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
                Text(
                  '$percentage%  ·  Осталось $timeStr',
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
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

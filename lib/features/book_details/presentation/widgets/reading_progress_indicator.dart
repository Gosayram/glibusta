import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class ReadingProgressIndicator extends StatelessWidget {
  final ReadingProgressData progress;

  const ReadingProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress.progressPercent > 0 ? progress.progressPercent.clamp(0.0, 1.0) : 0.0;
    final now = DateTime.now();
    final diff = now.difference(progress.lastRead);
    String lastReadText;
    if (diff.inMinutes < 1) {
      lastReadText = 'только что';
    } else if (diff.inHours < 1) {
      lastReadText = '${diff.inMinutes} мин назад';
    } else if (diff.inDays < 1) {
      lastReadText = '${diff.inHours} ч назад';
    } else if (diff.inDays < 7) {
      lastReadText = '${diff.inDays} дн назад';
    } else {
      lastReadText =
          '${progress.lastRead.day}.${progress.lastRead.month}.${progress.lastRead.year}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогресс чтения',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: percent, minHeight: 6),
          ),
          const SizedBox(height: 6),
          Text(
            'Читали $lastReadText',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

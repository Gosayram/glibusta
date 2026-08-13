import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/daos/reading_time_dao.dart';
import '../book_details_providers.dart';

class ReadingSummaryCard extends ConsumerWidget {
  final String bookId;

  const ReadingSummaryCard({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(bookReadingProgressProvider(bookId));
    final timeAsync = ref.watch(_totalReadingTimeProvider(bookId));
    final chaptersAsync = ref.watch(chaptersForBookProvider(bookId));

    return progressAsync.when(
      data: (progress) {
        if (progress == null) return const SizedBox.shrink();
        final totalMinutes = timeAsync.hasValue ? (timeAsync.value ?? 0) : 0;
        final totalChapters = chaptersAsync.hasValue
            ? (chaptersAsync.value?.chapters.length ?? 0)
            : 0;
        final readChapters = totalChapters > 0 ? progress.chapterIndex + 1 : 0;
        final percent = progress.progressPercent.clamp(0.0, 1.0);
        final theme = Theme.of(context);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Прогресс чтения',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(percent * 100).round()}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.menu_book,
                      label: totalChapters > 0
                          ? '$readChapters / $totalChapters'
                          : '${progress.chapterIndex + 1}',
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.timer,
                      label: _formatMinutes(totalMinutes),
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.schedule,
                      label: _formatRelativeDate(progress.lastRead),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _formatMinutes(int totalSeconds) {
    if (totalSeconds <= 0) return '0 мин';
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return '$minutes мин';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '$hours ч ${remaining > 0 ? '$remaining мин' : ''}';
  }

  static String _formatRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

final _totalReadingTimeProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  bookId,
) async {
  final dao = ref.watch(readingTimeDaoProvider);
  return dao.getTotalReadingSeconds(bookId);
});

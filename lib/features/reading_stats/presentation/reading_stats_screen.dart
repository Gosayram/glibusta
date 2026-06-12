import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/telemetry/reader_telemetry.dart' as telemetry;
import '../../home/presentation/reading_heatmap.dart';
import '../../home/presentation/reading_stats_provider.dart';
import '../../reading_goals/presentation/reading_goal_dialog.dart';
import '../../reading_goals/presentation/reading_goal_provider.dart';

final bookStatsListProvider = FutureProvider<Map<String, telemetry.BookStats>>((ref) async {
  final telemetryRepo = ref.watch(telemetry.readerTelemetryProvider);
  return telemetryRepo.getAllStats();
});

class ReadingStatsScreen extends ConsumerWidget {
  const ReadingStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(readingStatsProvider);
    final bookStatsAsync = ref.watch(bookStatsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика чтения'),
      ),
      body: statsAsync.when(
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCards(stats: stats),
              const SizedBox(height: 16),
              _GoalCard(todayMinutes: stats.todayMinutes),
              const SizedBox(height: 24),
              Text(
                'Активность',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ReadingHeatmap(data: stats.heatmapData),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'По книгам',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              bookStatsAsync.when(
                data: (bookStats) {
                  if (bookStats.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Пока нет данных о чтении',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final sorted = bookStats.entries.toList()
                    ..sort((a, b) => b.value.totalTime.compareTo(a.value.totalTime));

                  return Card(
                    child: Column(
                      children: sorted.take(10).map((entry) {
                        final bookId = entry.key;
                        final bs = entry.value;
                        final minutes = bs.totalTime.inMinutes;
                        final hours = minutes ~/ 60;
                        final mins = minutes % 60;
                        final timeStr = hours > 0
                            ? (mins > 0 ? '$hours ч $mins мин' : '$hours ч')
                            : '$mins мин';

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${bs.sessionsCount}'),
                          ),
                          title: Text(
                            'Книга ${bookId.substring(0, 8)}...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(timeStr),
                          trailing: Text(
                            '${bs.sessionsCount} сессий',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => context.push('/reader/$bookId'),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (Object e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Ошибка: $e'),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text('Не удалось загрузить статистику'),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final ReadingStats stats;

  const _SummaryCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon: Icons.local_fire_department,
          label: 'Серия',
          value: stats.currentStreak == 0 ? '—' : '${stats.currentStreak}',
          subtitle: stats.streakText,
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.today,
          label: 'Сегодня',
          value: stats.todayMinutes == 0 ? '—' : _formatMinutes(stats.todayMinutes),
          subtitle: stats.todayText,
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.calendar_view_week,
          label: 'За неделю',
          value: _formatMinutes(stats.thisWeekMinutes),
          subtitle: '${stats.thisWeekMinutes} мин',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.calendar_month,
          label: 'За месяц',
          value: _formatMinutes(stats.thisMonthMinutes),
          subtitle: stats.monthText,
          color: Colors.purple,
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m мин';
    return m > 0 ? '$h ч $m мин' : '$h ч';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final int todayMinutes;

  const _GoalCard({required this.todayMinutes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(readingGoalProvider);

    return goalAsync.when(
      data: (goal) {
        if (!goal.isEnabled) {
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ReadingGoalDialog.show(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Установить цель чтения',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Отслеживайте ежедневный прогресс',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final progress = todayMinutes / goal.dailyMinutes;
        final progressClamped = progress.clamp(0.0, 1.0);
        final isMet = progress >= 1.0;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ReadingGoalDialog.show(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isMet ? Icons.flag : Icons.flag_outlined,
                        color: isMet ? Colors.green : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Цель на сегодня',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isMet)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Выполнено!',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        )
                      else
                        Text(
                          '${(progressClamped * 100).round()}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progressClamped,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMet ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$todayMinutes мин',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        goal.displayText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

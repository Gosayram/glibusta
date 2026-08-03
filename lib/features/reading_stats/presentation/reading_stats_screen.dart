import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/stats_export_service.dart';
import '../../../core/telemetry/reader_telemetry.dart' as telemetry;
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../home/presentation/reading_heatmap.dart';
import '../../home/presentation/reading_stats_provider.dart';
import '../../reading_goals/data/weekly_reading_goal_progress.dart';
import '../../reading_goals/presentation/reading_goal_dialog.dart';
import '../../reading_goals/presentation/reading_goal_provider.dart';
import '../data/reading_milestones.dart';
import '../data/reading_stats_providers.dart' as rsp;
import '../data/reading_trend.dart';
import '../data/reading_trend_settings.dart';
import 'reading_trend_card.dart';

String _formatSessionDuration(int minutes) {
  if (minutes < 1) return '< 1 мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m мин';
  return m > 0 ? '$h ч $m мин' : '$h ч';
}

/// Explains the next useful step for an enabled daily reading goal.
String formatDailyGoalProgressMessage({
  required int todayMinutes,
  required int goalMinutes,
}) {
  if (todayMinutes == goalMinutes) return 'Цель выполнена точно';
  return todayMinutes > goalMinutes
      ? 'На ${todayMinutes - goalMinutes} мин больше цели'
      : 'Осталось ${goalMinutes - todayMinutes} мин';
}

class ReadingStatsScreen extends ConsumerWidget {
  const ReadingStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(readingStatsProvider);
    final bookStatsAsync = ref.watch(rsp.bookStatsListProvider);
    final favGenresAsync = ref.watch(rsp.favoriteGenresProvider);

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Статистика чтения'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) => _handleExport(context, ref, value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'json', child: Text('Экспорт JSON')),
              const PopupMenuItem(value: 'csv', child: Text('Экспорт CSV')),
            ],
          ),
        ],
      ),
      body: statsAsync.when(
        data: (ReadingStats stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakBanner(stats: stats),
              const SizedBox(height: 12),
              _TodayProgressCard(todayMinutes: stats.todayMinutes),
              const SizedBox(height: 16),
              _SummaryCards(stats: stats),
              const SizedBox(height: 16),
              _WpmCard(averageWpm: stats.averageWpm, trend: stats.wpmTrend),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.timeline, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Средняя сессия',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        _formatMinutes(stats.avgSessionMinutes.round()),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _TimeTrackingCards(
                todayMinutes: stats.todayMinutes,
                weekMinutes: stats.thisWeekMinutes,
              ),
              const SizedBox(height: 16),
              _GoalCard(
                todayMinutes: stats.todayMinutes,
                thisWeekMinutes: stats.thisWeekMinutes,
              ),
              const SizedBox(height: 24),
              _LocalMilestonesCard(stats: stats),
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
              _WeeklyGoalChart(readings: stats.heatmapData),
              const SizedBox(height: 24),
              Text(
                'Ритм чтения',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _ReadingTrendCard(readings: stats.heatmapData),
              const SizedBox(height: 24),
              Text(
                'Время чтения',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _ReadingHoursChart(),
              const SizedBox(height: 24),
              Text(
                'Любимые жанры',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              favGenresAsync.when(
                data: (genres) {
                  if (genres.isEmpty) return const SizedBox.shrink();
                  final maxCount = genres.first.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: genres.map((entry) {
                          final ratio = entry.value / maxCount;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    entry.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 12,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${entry.value}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
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
                data: (Map<String, telemetry.BookStats> bookStats) {
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
                      children: sorted.take(10).map((MapEntry<String, telemetry.BookStats> entry) {
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
                            'Книга ${bookId.substring(0, bookId.length > 8 ? 8 : bookId.length)}...',
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

  Future<void> _handleExport(BuildContext context, WidgetRef ref, String format) async {
    try {
      final exportService = ref.read(statsExportServiceProvider);
      if (format == 'json') {
        await exportService.shareJson();
      } else {
        await exportService.shareCsv();
      }
    } on Object catch (e) {
      if (!context.mounted) return;
      unawaited(SmartDialog.showToast('Ошибка экспорта: $e'));
    }
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.stats});

  final ReadingStats stats;

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
          icon: Icons.auto_stories,
          label: 'Страниц сегодня',
          value: stats.todayPages == 0 ? '—' : '${stats.todayPages}',
          subtitle: '${stats.todayPages} стр.',
          color: Colors.teal,
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
}

class _TimeTrackingCards extends ConsumerWidget {
  const _TimeTrackingCards({required this.todayMinutes, required this.weekMinutes});

  final int todayMinutes;
  final int weekMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStart = ref.watch(rsp.currentSessionStartProvider);
    ref.watch(rsp.sessionTimerProvider);

    final sessionMinutes = sessionStart != null
        ? DateTime.now().difference(sessionStart).inMinutes
        : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Время сегодня',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        todayMinutes == 0 ? '—' : _formatSessionDuration(todayMinutes),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.date_range,
                            size: 16,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Время за неделю',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weekMinutes == 0 ? '—' : _formatSessionDuration(weekMinutes),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 20,
                  color: sessionStart != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущая сессия',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (sessionStart != null)
                      Text(
                        'начата в ${sessionStart.hour.toString().padLeft(2, '0')}:${sessionStart.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  sessionStart != null ? _formatSessionDuration(sessionMinutes) : 'Нет сессии',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: sessionStart != null ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m мин';
  return m > 0 ? '$h ч $m мин' : '$h ч';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

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

class _LocalMilestonesCard extends StatelessWidget {
  const _LocalMilestonesCard({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final milestones = buildLocalReadingMilestones(
      totalMinutes: stats.totalMinutes,
      totalSessions: stats.totalSessions,
      longestStreak: stats.longestStreak,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Локальные достижения',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Считаются только по сохранённым данным на этом устройстве',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final milestone in milestones) ...[
                  Semantics(
                    label: milestone.title,
                    value:
                        '${milestone.progressLabel}. '
                        '${milestone.isUnlocked ? 'Достигнуто' : 'В процессе'}',
                    child: _MilestoneRow(milestone: milestone),
                  ),
                  if (milestone != milestones.last) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone});

  final ReadingMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unlocked = milestone.isUnlocked;
    final color = unlocked ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return ExcludeSemantics(
      child: Row(
        children: [
          Icon(unlocked ? Icons.workspace_premium_outlined : Icons.flag_outlined, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  milestone.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: milestone.progress),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            milestone.progressLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ReadingTrendCard extends ConsumerWidget {
  const _ReadingTrendCard({required this.readings});

  final List<DayReading> readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingTrendSettingsProvider);

    return settingsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (settings) {
        final notifier = ref.read(readingTrendSettingsProvider.notifier);
        if (!settings.isEnabled) {
          return Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.insights_outlined),
              title: const Text('Локальный тренд'),
              subtitle: const Text('Показывать ритм чтения только на этом устройстве'),
              value: false,
              onChanged: (enabled) => notifier.saveSettings(settings.copyWith(isEnabled: enabled)),
            ),
          );
        }

        final trend = buildReadingMinutesTrend(
          readings: readings,
          endingAt: DateTime.now(),
          period: settings.period,
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Локальный тренд',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Switch(
                      value: true,
                      onChanged: (enabled) =>
                          notifier.saveSettings(settings.copyWith(isEnabled: enabled)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<ReadingTrendPeriod>(
                  segments: ReadingTrendPeriod.values
                      .map(
                        (period) => ButtonSegment<ReadingTrendPeriod>(
                          value: period,
                          label: Text(period.label),
                        ),
                      )
                      .toList(),
                  selected: {settings.period},
                  onSelectionChanged: (selection) {
                    final period = selection.firstOrNull;
                    if (period != null) {
                      unawaited(notifier.saveSettings(settings.copyWith(period: period)));
                    }
                  },
                ),
                const SizedBox(height: 16),
                ReadingTrendChart(trend: trend),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.todayMinutes,
    required this.thisWeekMinutes,
  });

  final int todayMinutes;
  final int thisWeekMinutes;

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
        final progressMessage = formatDailyGoalProgressMessage(
          todayMinutes: todayMinutes,
          goalMinutes: goal.dailyMinutes,
        );
        final weeklyProgress = calculateWeeklyReadingGoalProgress(
          dailyGoalMinutes: goal.dailyMinutes,
          weekMinutes: thisWeekMinutes,
        );
        final weeklyMessage = formatWeeklyGoalProgressMessage(weeklyProgress);

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
                        progressMessage,
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        weeklyProgress.isComplete
                            ? Icons.calendar_month
                            : Icons.calendar_month_outlined,
                        color: weeklyProgress.isComplete
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ритм за неделю',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${weeklyProgress.completedMinutes} из ${weeklyProgress.targetMinutes} мин',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: weeklyProgress.completion,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      weeklyProgress.isComplete
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weeklyMessage,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _ReadingHoursChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoursAsync = ref.watch(rsp.readingHoursProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hoursAsync.when(
          data: (hours) {
            final maxVal = hours.cast<num?>().reduce(
              (a, b) => (a ?? 0) > (b ?? 0) ? a : b,
            );
            if (maxVal == null || maxVal == 0) {
              return const SizedBox(
                height: 60,
                child: Center(child: Text('Нет данных')),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'По часам',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(24, (i) {
                      final value = hours[i];
                      final ratio = maxVal > 0 ? value / maxVal : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: ratio > 0
                                        ? Theme.of(context).colorScheme.primary.withValues(
                                            alpha: 0.3 + ratio * 0.7,
                                          )
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '$i',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => const SizedBox(
            height: 60,
            child: Center(child: Text('Ошибка')),
          ),
        ),
      ),
    );
  }
}

class _WpmCard extends StatelessWidget {
  const _WpmCard({required this.averageWpm, required this.trend});

  final double averageWpm;
  final WpmTrend trend;

  @override
  Widget build(BuildContext context) {
    if (averageWpm <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 12),
              Text(
                'Средняя скорость',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                '—',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final trendIcon = switch (trend) {
      WpmTrend.up => Icons.trending_up,
      WpmTrend.down => Icons.trending_down,
      WpmTrend.stable => Icons.trending_flat,
      WpmTrend.unknown => null,
    };
    final trendColor = switch (trend) {
      WpmTrend.up => Colors.green,
      WpmTrend.down => Colors.red,
      WpmTrend.stable => Colors.grey,
      WpmTrend.unknown => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.speed, size: 20),
            const SizedBox(width: 12),
            Text(
              'Средняя скорость',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            if (trendIcon != null) ...[
              Icon(trendIcon, size: 18, color: trendColor),
              const SizedBox(width: 4),
            ],
            Text(
              '${averageWpm.round()} WPM',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final streak = stats.currentStreak;
    final colorScheme = Theme.of(context).colorScheme;

    final String streakLabel;
    final String streakSubtitle;
    final Color bgColor;

    if (streak == 0) {
      streakLabel = '0';
      streakSubtitle = 'Начните читать сегодня!';
      bgColor = colorScheme.surfaceContainerHighest;
    } else if (streak == 1) {
      streakLabel = '1';
      streakSubtitle = '1 день подряд';
      bgColor = Colors.orange.shade50;
    } else {
      streakLabel = '$streak';
      streakSubtitle = '$streak дней подряд';
      bgColor = Colors.orange.shade50;
    }

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streakLabel,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: streak > 0 ? Colors.orange.shade800 : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    streakSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: streak > 0 ? Colors.orange.shade700 : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (stats.longestStreak > streak)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Рекорд',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${stats.longestStreak}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayProgressCard extends ConsumerWidget {
  const _TodayProgressCard({required this.todayMinutes});

  final int todayMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(readingGoalProvider);

    return goalAsync.when(
      data: (goal) {
        if (!goal.isEnabled) return const SizedBox.shrink();

        final progress = (todayMinutes / goal.dailyMinutes).clamp(0.0, 1.0);
        final isMet = todayMinutes >= goal.dailyMinutes;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isMet ? Icons.check_circle : Icons.today,
                      size: 20,
                      color: isMet ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Сегодня',
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
                          '🎉',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    Text(
                      '$todayMinutes из ${goal.dailyMinutes} мин',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMet ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatDailyGoalProgressMessage(
                    todayMinutes: todayMinutes,
                    goalMinutes: goal.dailyMinutes,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
}

class _WeeklyGoalChart extends ConsumerWidget {
  const _WeeklyGoalChart({required this.readings});

  final List<DayReading> readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(readingGoalProvider);

    return goalAsync.when(
      data: (goal) {
        if (!goal.isEnabled) return const SizedBox.shrink();

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final dailyMinutesMap = <DateTime, int>{};
        for (final r in readings) {
          final day = DateTime(r.date.year, r.date.month, r.date.day);
          dailyMinutesMap[day] = (dailyMinutesMap[day] ?? 0) + r.minutes;
        }

        final days = List<int>.generate(7, (i) {
          final day = todayStart.subtract(Duration(days: 6 - i));
          return dailyMinutesMap[day] ?? 0;
        });
        final maxMinutes = days.cast<int>().fold<int>(0, (a, b) => b > a ? b : a);
        final dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогресс за неделю',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final minutes = days[i];
                      final metGoal = minutes >= goal.dailyMinutes;
                      final ratio = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: ratio,
                                    widthFactor: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: metGoal
                                            ? Colors.green
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dayLabels[(todayStart.weekday - 7 + i) % 7],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Цель достигнута',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 12,
                      height: 12,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Не достигнута',
                      style: Theme.of(context).textTheme.labelSmall,
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
}

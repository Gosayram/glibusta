import 'package:flutter/material.dart';

import 'reading_stats_provider.dart';

class ReadingHeatmap extends StatelessWidget {
  final List<DayReading> data;

  const ReadingHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (data.isEmpty) return const SizedBox.shrink();

    // Group by weeks (7 days each)
    final weeks = <List<DayReading>>[];
    for (int i = 0; i < data.length; i += 7) {
      final end = (i + 7 < data.length) ? i + 7 : data.length;
      weeks.add(data.sublist(i, end));
    }

    final maxMinutes = data.fold<int>(0, (max, d) => d.minutes > max ? d.minutes : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        Row(
          children: [
            for (int i = 0; i < weeks.length; i += 4)
              Padding(
                padding: EdgeInsets.only(left: i * 14.0),
                child: Text(
                  _monthLabel(weeks[i].first.date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Heatmap grid
        Row(
          children: [
            // Day labels
            Column(
              children: [
                _dayLabel('Пн', theme),
                const SizedBox(height: 2),
                _dayLabel('Ср', theme),
                const SizedBox(height: 2),
                _dayLabel('Пт', theme),
              ],
            ),
            const SizedBox(width: 4),
            // Weeks
            ...weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Column(
                  children: List.generate(7, (dayIndex) {
                    if (dayIndex >= week.length) {
                      return const SizedBox(width: 12, height: 12);
                    }
                    final day = week[dayIndex];
                    final intensity = maxMinutes > 0
                        ? (day.minutes / maxMinutes).clamp(0.0, 1.0)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Tooltip(
                        message: '${_formatDate(day.date)}: ${day.minutes} мин',
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getColor(intensity, colorScheme),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
        // Legend
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Меньше',
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            for (int i = 0; i <= 4; i++)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: _getColor(i / 4, colorScheme),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              'Больше',
              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColor(double intensity, ColorScheme colorScheme) {
    if (intensity <= 0) return colorScheme.surfaceContainerHighest;
    if (intensity < 0.25) return colorScheme.primary.withValues(alpha: 0.2);
    if (intensity < 0.5) return colorScheme.primary.withValues(alpha: 0.4);
    if (intensity < 0.75) return colorScheme.primary.withValues(alpha: 0.65);
    return colorScheme.primary;
  }

  Widget _dayLabel(String text, ThemeData theme) {
    return SizedBox(
      width: 16,
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(fontSize: 8),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Янв',
      'Фев',
      'Мар',
      'Апр',
      'Май',
      'Июн',
      'Июл',
      'Авг',
      'Сен',
      'Окт',
      'Ноя',
      'Дек',
    ];
    return months[date.month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}

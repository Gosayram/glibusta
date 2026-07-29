import 'package:flutter/material.dart';

import '../data/reading_trend.dart';

/// A compact local-only visualisation of daily reading time.
class ReadingTrendChart extends StatelessWidget {
  const ReadingTrendChart({
    required this.trend,
    super.key,
  });

  final List<ReadingTrendDay> trend;

  @override
  Widget build(BuildContext context) {
    final maximum = trend.fold<int>(
      0,
      (current, day) => day.minutes > current ? day.minutes : current,
    );
    final total = trend.fold<int>(0, (current, day) => current + day.minutes);
    final activeDays = trend.where((day) => day.minutes > 0).length;
    final activeDaysLabel = activeDays == 1 ? '1 активный день' : '$activeDays активных дней';

    return Semantics(
      label: 'Ритм чтения: $activeDaysLabel, $total минут за выбранный период',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trend.map((day) {
                  final ratio = maximum == 0 ? 0.0 : day.minutes / maximum;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: ratio,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              activeDays == 0
                  ? 'Пока нет чтения в выбранный период'
                  : '$activeDays из ${trend.length} дней с чтением',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

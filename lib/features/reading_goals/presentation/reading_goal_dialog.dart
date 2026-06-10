import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_goal_repository.dart';
import 'reading_goal_provider.dart';

class ReadingGoalDialog extends ConsumerStatefulWidget {
  const ReadingGoalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ReadingGoalDialog(),
    );
  }

  @override
  ConsumerState<ReadingGoalDialog> createState() => _ReadingGoalDialogState();
}

class _ReadingGoalDialogState extends ConsumerState<ReadingGoalDialog> {
  late double _dailyMinutes;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    final asyncGoal = ref.read(readingGoalProvider);
    asyncGoal.whenData((goal) {
      setState(() {
        _dailyMinutes = goal.dailyMinutes.toDouble();
        _isEnabled = goal.isEnabled;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Цель чтения'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Включить цель'),
            subtitle: const Text('Отслеживать ежедневное чтение'),
            value: _isEnabled,
            onChanged: (value) => setState(() => _isEnabled = value),
            contentPadding: EdgeInsets.zero,
          ),
          if (_isEnabled) ...[
            const SizedBox(height: 16),
            Text(
              _formatMinutes(_dailyMinutes.round()),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _dailyMinutes,
              min: 5,
              max: 180,
              divisions: 35,
              label: _formatMinutes(_dailyMinutes.round()),
              onChanged: (value) => setState(() => _dailyMinutes = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '5 мин',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '3 ч',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
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

  Future<void> _save() async {
    final goal = ReadingGoal(
      dailyMinutes: _dailyMinutes.round(),
      isEnabled: _isEnabled,
    );
    final repo = await ref.read(readingGoalRepositoryProvider.future);
    await repo.saveGoal(goal);
    ref.invalidate(readingGoalProvider);
    if (mounted) Navigator.of(context).pop();
  }
}

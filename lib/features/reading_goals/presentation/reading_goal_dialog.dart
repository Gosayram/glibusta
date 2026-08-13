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
  late final ProviderSubscription<AsyncValue<ReadingGoal>> _goalSubscription;
  double _dailyMinutes = 30;
  bool _isEnabled = false;
  bool _hasLoadedGoal = false;

  @override
  void initState() {
    super.initState();
    _goalSubscription = ref.listenManual(
      readingGoalProvider,
      (_, next) => next.whenData(_loadInitialGoal),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _goalSubscription.close();
    super.dispose();
  }

  void _loadInitialGoal(ReadingGoal goal) {
    if (_hasLoadedGoal) return;
    _dailyMinutes = goal.dailyMinutes.toDouble().clamp(5.0, 180.0);
    _isEnabled = goal.isEnabled;
    _hasLoadedGoal = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(readingGoalProvider);
    if (!_hasLoadedGoal) {
      return goal.when(
        loading: _LoadingReadingGoalDialog.new,
        error: (error, _) => _ReadingGoalLoadErrorDialog(
          onRetry: () => ref.invalidate(readingGoalProvider),
        ),
        data: (_) => const _LoadingReadingGoalDialog(),
      );
    }

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
    try {
      final repo = await ref.read(readingGoalRepositoryProvider.future);
      await repo.saveGoal(goal);
      ref.invalidate(readingGoalProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }
}

class _LoadingReadingGoalDialog extends StatelessWidget {
  const _LoadingReadingGoalDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text('Цель чтения'),
      content: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Text('Загружаем настройки…'),
        ],
      ),
    );
  }
}

class _ReadingGoalLoadErrorDialog extends StatelessWidget {
  const _ReadingGoalLoadErrorDialog({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Цель чтения'),
      content: const Text('Не удалось загрузить настройки цели.'),
      actions: [
        TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    );
  }
}

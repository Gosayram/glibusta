import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'background_task_provider.dart';

class _QueuedTask<T> {
  _QueuedTask({
    required this.type,
    required this.message,
    required this.task,
    required this.completer,
    this.successMessage,
  });

  final BackgroundTaskType type;
  final String message;
  final Future<T> Function() task;
  final Completer<T> completer;
  final String Function(T result)? successMessage;
}

class TaskQueueService {
  TaskQueueService(this._notifier, {int? maxConcurrent}) : maxConcurrent = maxConcurrent ?? 3;

  final BackgroundTaskNotifier _notifier;
  final int maxConcurrent;
  final _queue = <_QueuedTask<Object?>>[];
  int _running = 0;
  final _logger = AppLogger();

  int get pendingCount => _queue.length;
  int get runningCount => _running;

  Future<T> run<T>({
    required BackgroundTaskType type,
    required String message,
    required Future<T> Function() task,
    String Function(T result)? successMessage,
  }) {
    final completer = Completer<T>();
    final queued = _QueuedTask<T>(
      type: type,
      message: message,
      task: task,
      completer: completer,
      successMessage: successMessage,
    );
    _queue.add(queued as _QueuedTask<Object?>);
    _logger.info(
      'Task queued: $message (pending: ${_queue.length}, running: $_running)',
      name: 'TaskQueue',
    );
    _processNext();
    return completer.future;
  }

  void _processNext() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _running++;
      unawaited(_execute(next));
    }
  }

  Future<void> _execute<T>(_QueuedTask<T> queued) async {
    final taskId = _notifier.start(queued.type, queued.message);
    try {
      final result = await queued.task();
      final msg = queued.successMessage?.call(result);
      _notifier.complete(taskId, msg);
      queued.completer.complete(result);
    } on Object catch (e, st) {
      _notifier.fail(taskId, e.toString());
      _logger.warning(
        'Task failed: ${queued.message}: $e',
        name: 'TaskQueue',
        error: e,
        st: st,
      );
      queued.completer.completeError(e, st);
    } finally {
      _running--;
      _processNext();
    }
  }
}

final taskQueueProvider = Provider<TaskQueueService>((ref) {
  return TaskQueueService(ref.watch(backgroundTaskProvider.notifier));
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TaskPriority { critical, high, normal, low }

enum TaskStatus { pending, running, completed, failed, cancelled }

enum TaskType { download, parse, extractCover, indexBook, syncProgress, cleanup, import }

abstract class Task {
  Task({
    required this.id,
    required this.type,
    this.priority = TaskPriority.normal,
    this.dependsOn,
  });

  final String id;
  final TaskType type;
  final TaskPriority priority;
  final String? dependsOn;

  TaskStatus _status = TaskStatus.pending;
  TaskStatus get status => _status;

  int _retryCount = 0;

  Future<void> execute();
  void cancel() => _status = TaskStatus.cancelled;
  bool get shouldRetry => false;
  int get maxRetries => 0;
}

class DownloadTask extends Task {
  DownloadTask({
    required super.id,
    required this.url,
    required this.savePath,
    super.priority = TaskPriority.normal,
  }) : super(type: TaskType.download);

  final String url;
  final String savePath;

  @override
  Future<void> execute() async {
    // Delegate to DownloadService
  }
}

class ParseTask extends Task {
  ParseTask({
    required super.id,
    required this.filePath,
    super.priority = TaskPriority.normal,
    super.dependsOn,
  }) : super(type: TaskType.parse);

  final String filePath;

  @override
  Future<void> execute() async {}
}

class IndexBookTask extends Task {
  IndexBookTask({
    required super.id,
    required this.bookId,
    super.priority = TaskPriority.low,
    super.dependsOn,
  }) : super(type: TaskType.indexBook);

  final String bookId;

  @override
  Future<void> execute() async {}
}

class CleanupTask extends Task {
  CleanupTask({
    required super.id,
    required this.target,
    super.priority = TaskPriority.low,
  }) : super(type: TaskType.cleanup);

  final String target;

  @override
  Future<void> execute() async {}
}

class TaskQueue {
  TaskQueue({this.maxConcurrent = 3});

  final int maxConcurrent;
  final List<Task> _pending = [];
  final Map<String, Task> _allTasks = {};
  int _runningCount = 0;
  bool _paused = false;
  final _controller = StreamController<Task>.broadcast();

  Stream<Task> get taskStream => _controller.stream;
  int get pendingCount => _pending.length;
  int get runningCount => _runningCount;
  int get totalCount => _allTasks.length;
  bool get isPaused => _paused;
  List<Task> get pendingTasks => List.unmodifiable(_pending);
  List<Task> get activeTasks =>
      _allTasks.values.where((t) => t.status == TaskStatus.running).toList();

  void add(Task task) {
    _allTasks[task.id] = task;
    _pending.add(task);
    _pending.sort((a, b) => _comparePriority(a.priority, b.priority));
    _processNext();
  }

  void addAll(List<Task> tasks) {
    for (final task in tasks) {
      _allTasks[task.id] = task;
      _pending.add(task);
    }
    _pending.sort((a, b) => _comparePriority(a.priority, b.priority));
    _processNext();
  }

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
    _processNext();
  }

  void cancel(String taskId) {
    final task = _allTasks[taskId];
    if (task != null) {
      task.cancel();
      _pending.remove(task);
      _allTasks.remove(taskId);
    }
  }

  void cancelAll() {
    for (final task in _allTasks.values) {
      task.cancel();
    }
    _pending.clear();
    _allTasks.clear();
    _runningCount = 0;
  }

  void removeCompleted() {
    final completed = _allTasks.values
        .where((t) => t.status == TaskStatus.completed || t.status == TaskStatus.cancelled)
        .map((t) => t.id)
        .toList();
    for (final id in completed) {
      _allTasks.remove(id);
    }
  }

  Task? findTask(String taskId) => _allTasks[taskId];

  bool hasDependency(String taskId) {
    final task = _allTasks[taskId];
    if (task?.dependsOn == null) return false;
    final dep = _allTasks[task!.dependsOn!];
    return dep != null && dep.status != TaskStatus.completed;
  }

  void _processNext() {
    if (_paused) return;
    if (_runningCount >= maxConcurrent) return;
    if (_pending.isEmpty) return;

    final task = _pending.first;
    if (task.status == TaskStatus.cancelled) {
      _pending.removeAt(0);
      _processNext();
      return;
    }

    if (hasDependency(task.id)) return;

    _pending.removeAt(0);
    _runningCount++;
    task._status = TaskStatus.running;
    _controller.add(task);

    unawaited(
      task
          .execute()
          .then((_) {
            task._status = TaskStatus.completed;
            _runningCount--;
            _controller.add(task);
            _processNext();
          })
          .catchError((Object _, StackTrace _) {
            if (task.shouldRetry && task._retryCount < task.maxRetries) {
              task._retryCount++;
              task._status = TaskStatus.pending;
              _runningCount--;
              _pending.add(task);
              _pending.sort((a, b) => _comparePriority(a.priority, b.priority));
              _processNext();
            } else {
              task._status = TaskStatus.failed;
              _runningCount--;
              _controller.add(task);
              _processNext();
            }
          }),
    );
  }

  void dispose() {
    cancelAll();
    unawaited(_controller.close());
  }

  static int _comparePriority(TaskPriority a, TaskPriority b) {
    const order = {
      TaskPriority.critical: 0,
      TaskPriority.high: 1,
      TaskPriority.normal: 2,
      TaskPriority.low: 3,
    };
    return order[a]!.compareTo(order[b]!);
  }
}

// --- Riverpod providers ---

final taskQueueProvider = Provider<TaskQueue>((ref) {
  final queue = TaskQueue();
  ref.onDispose(queue.dispose);
  return queue;
});

final taskQueueStatsProvider = Provider<Map<String, int>>((ref) {
  final queue = ref.watch(taskQueueProvider);
  return {
    'pending': queue.pendingCount,
    'running': queue.runningCount,
    'total': queue.totalCount,
  };
});

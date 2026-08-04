import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BackgroundTaskType { import, coverExtraction, directoryScan, cacheClear }

enum BackgroundTaskStatus { running, completed, failed }

class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.type,
    required this.status,
    required this.message,
    required this.startedAt,
    this.completedAt,
  });

  final String id;
  final BackgroundTaskType type;
  final BackgroundTaskStatus status;
  final String message;
  final DateTime startedAt;
  final DateTime? completedAt;

  BackgroundTask copyWith({
    BackgroundTaskStatus? status,
    String? message,
    DateTime? completedAt,
  }) {
    return BackgroundTask(
      id: id,
      type: type,
      status: status ?? this.status,
      message: message ?? this.message,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class BackgroundTaskNotifier extends Notifier<List<BackgroundTask>> {
  var _nextId = 0;

  @override
  List<BackgroundTask> build() => [];

  String start(BackgroundTaskType type, String message) {
    final id = '${type.name}_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}';
    final task = BackgroundTask(
      id: id,
      type: type,
      status: BackgroundTaskStatus.running,
      message: message,
      startedAt: DateTime.now(),
    );
    state = [...state, task];
    return id;
  }

  void complete(String id, [String? message]) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            status: BackgroundTaskStatus.completed,
            message: message ?? task.message,
            completedAt: DateTime.now(),
          )
        else
          task,
    ];
  }

  void fail(String id, String error) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            status: BackgroundTaskStatus.failed,
            message: error,
            completedAt: DateTime.now(),
          )
        else
          task,
    ];
  }

  void clearCompleted() {
    state = state.where((t) => t.status == BackgroundTaskStatus.running).toList();
  }

  List<BackgroundTask> get running =>
      state.where((t) => t.status == BackgroundTaskStatus.running).toList();
}

final backgroundTaskProvider = NotifierProvider<BackgroundTaskNotifier, List<BackgroundTask>>(
  BackgroundTaskNotifier.new,
);

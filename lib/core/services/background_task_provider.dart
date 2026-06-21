import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_task_provider.freezed.dart';

enum BackgroundTaskType { import, coverExtraction, directoryScan, cacheClear }

enum BackgroundTaskStatus { running, completed, failed }

@freezed
abstract class BackgroundTask with _$BackgroundTask {
  const factory BackgroundTask({
    required String id,
    required BackgroundTaskType type,
    required BackgroundTaskStatus status,
    required String message,
    required DateTime startedAt,
    DateTime? completedAt,
  }) = _BackgroundTask;

  const BackgroundTask._();
}

class BackgroundTaskNotifier extends Notifier<List<BackgroundTask>> {
  @override
  List<BackgroundTask> build() => [];

  String start(BackgroundTaskType type, String message) {
    final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
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
    _scheduleCleanup(id);
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
    _scheduleCleanup(id);
  }

  void _scheduleCleanup(String id) {
    Future.delayed(const Duration(seconds: 5), () {
      state = state.where((t) => t.id != id).toList();
    });
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/services/background_task_provider.dart';
import 'package:glibusta/core/services/task_queue_service.dart';

void main() {
  test('normalizes a non-positive concurrency limit so tasks cannot hang', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final queue = TaskQueueService(
      container.read(backgroundTaskProvider.notifier),
      maxConcurrent: 0,
    );

    final result = await queue
        .run<int>(
          type: BackgroundTaskType.directoryScan,
          message: 'scan',
          task: () async => 42,
        )
        .timeout(const Duration(seconds: 1));

    expect(queue.maxConcurrent, 1);
    expect(result, 42);
    expect(queue.pendingCount, isZero);
    expect(queue.runningCount, isZero);
  });
}

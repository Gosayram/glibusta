import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/services/background_task_provider.dart';

void main() {
  test('assigns unique IDs to concurrent tasks of the same type', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(backgroundTaskProvider.notifier);

    final firstId = notifier.start(BackgroundTaskType.directoryScan, 'first scan');
    final secondId = notifier.start(BackgroundTaskType.directoryScan, 'second scan');

    expect(firstId, isNot(secondId));
    expect(container.read(backgroundTaskProvider).map((task) => task.id).toSet(), hasLength(2));
  });
}

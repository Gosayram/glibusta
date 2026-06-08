import 'dart:async';
import 'package:collection/collection.dart';
import '../../../shared/models/download_task.dart';

class DownloadQueue {
  final StreamController<DownloadTask> _progressController =
      StreamController<DownloadTask>.broadcast();

  Stream<DownloadTask> get onProgress => _progressController.stream;

  final PriorityQueue<DownloadTask> _queue = PriorityQueue<DownloadTask>((a, b) {
    return a.status.index.compareTo(b.status.index);
  });

  Future<void> enqueue(DownloadTask task) async {
    _queue.add(task);
  }

  Future<void> pause(String taskId) async {
    // Implementation will be added
  }

  Future<void> resume(String taskId) async {
    // Implementation will be added
  }

  Future<void> cancel(String taskId) async {
    // Implementation will be added
  }

  void dispose() {
    _progressController.close();
  }
}
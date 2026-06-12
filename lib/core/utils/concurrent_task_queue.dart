import 'dart:async';

class ConcurrentTaskQueue {
  ConcurrentTaskQueue({this.maxConcurrent = 4});
  final int maxConcurrent;
  final List<Future<dynamic>> _running = [];
  final List<Completer<void>> _waiting = [];

  int get pendingCount => _waiting.length;
  int get runningCount => _running.length;

  Future<T> enqueue<T>(Future<T> Function() task) async {
    while (_running.length >= maxConcurrent) {
      final completer = Completer<void>();
      _waiting.add(completer);
      await completer.future;
    }

    final future = task();
    final entry = future;
    _running.add(entry);

    try {
      return await future;
    } finally {
      _running.remove(entry);
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      }
    }
  }

  void dispose() {
    for (final w in _waiting) {
      w.completeError(StateError('Queue disposed'));
    }
    _waiting.clear();
  }
}

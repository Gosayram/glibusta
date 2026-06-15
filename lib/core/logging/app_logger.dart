import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../events/app_events.dart';

enum LogLevel { finest, fine, info, warning, severe, shout }

class LogEntry {
  const LogEntry({
    required this.level,
    required this.message,
    required this.time,
    this.loggerName,
    this.error,
    this.stackTrace,
  });

  final String level;
  final String message;
  final DateTime time;
  final String? loggerName;
  final Object? error;
  final StackTrace? stackTrace;

  String toLine() {
    final sb = StringBuffer()
      ..write('[')
      ..write(time.toIso8601String())
      ..write('] ')
      ..write(level.padRight(8))
      ..write(' ')
      ..write(loggerName ?? '')
      ..write(': ')
      ..write(message);
    if (error != null) {
      sb.write(' | ERROR: $error');
    }
    return sb.toString();
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'message': message,
    'ts': time.toIso8601String(),
    if (loggerName != null) 'logger': loggerName,
    if (error != null) 'error': error.toString(),
  };
}

class AppLogger {
  static final AppLogger _singleton = AppLogger._internal();

  factory AppLogger() => _singleton;

  AppLogger._internal({int bufferSize = 500}) : _ringBuffer = _RingBuffer<LogEntry>(bufferSize);

  final _RingBuffer<LogEntry> _ringBuffer;
  final _controller = StreamController<LogEntry>.broadcast();
  final List<void Function(LogEntry)> _listeners = [];

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get entries => _ringBuffer.toList();
  LogEntry? get lastEntry => _ringBuffer.last;

  void log(
    String level,
    String message, {
    String? loggerName,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      level: level,
      message: message,
      time: DateTime.now(),
      loggerName: loggerName,
      error: error,
      stackTrace: stackTrace,
    );
    _ringBuffer.add(entry);
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
    for (final listener in _listeners) {
      listener(entry);
    }

    final name = loggerName ?? 'App';
    final errorSuffix = error != null ? ' | $error' : '';
    final traceSuffix = stackTrace != null ? '\n$stackTrace' : '';
    developer.log('$level: $message$errorSuffix$traceSuffix', name: name, level: _levelInt(level));

    if (level == 'WARNING' || level == 'SEVERE' || level == 'SHOUT') {
      unawaited(_persistLog(entry));
    }
  }

  static int _levelInt(String level) {
    return switch (level) {
      'FINEST' => 300,
      'FINE' => 500,
      'INFO' => 800,
      'WARNING' => 900,
      'SEVERE' => 1000,
      'SHOUT' => 1200,
      _ => 800,
    };
  }

  static const int _maxPersistentLogBytes = 2 * 1024 * 1024;

  Future<void> _persistLog(LogEntry entry) async {
    try {
      final line = entry.toLine();
      if (line.isNotEmpty) {
        final dir = await getApplicationSupportDirectory();
        final logDir = Directory('${dir.path}/logs');
        await logDir.create(recursive: true);
        final file = File('${logDir.path}/glibusta.log');
        await _rotateIfNeeded(file);
        final sink = file.openWrite(mode: FileMode.append);
        sink.writeln(line);
        await sink.flush();
        await sink.close();
      }
    } on Object catch (_) {}
    if (entry.level == 'SEVERE' || entry.level == 'SHOUT') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final summary = entry.error != null ? '${entry.message} | ${entry.error}' : entry.message;
        await prefs.setString('last_error', summary);
      } on Object catch (_) {}
    }
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    final stat = await file.stat();
    if (stat.size > _maxPersistentLogBytes) {
      final backup = File('${file.path}.old');
      if (await backup.exists()) {
        await backup.delete();
      }
      await file.rename(backup.path);
    }
  }

  void finest(String msg, {String? name}) => log('FINEST', msg, loggerName: name);
  void fine(String msg, {String? name}) => log('FINE', msg, loggerName: name);
  void info(String msg, {String? name}) => log('INFO', msg, loggerName: name);
  void warning(String msg, {String? name, Object? error, StackTrace? st}) =>
      log('WARNING', msg, loggerName: name, error: error, stackTrace: st);
  void severe(String msg, {String? name, Object? error, StackTrace? st}) =>
      log('SEVERE', msg, loggerName: name, error: error, stackTrace: st);

  void addListener(void Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  Future<String> exportToFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/logs/glibusta_${DateTime.now().millisecondsSinceEpoch}.log');
    await file.parent.create(recursive: true);
    final lines = _ringBuffer.toList().map((e) => e.toLine()).join('\n');
    await file.writeAsString(lines);
    return file.path;
  }

  String exportAsText() {
    return _ringBuffer.toList().map((e) => e.toLine()).join('\n');
  }

  Future<String> readPersistentLog() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/logs/glibusta.log');
      final oldFile = File('${dir.path}/logs/glibusta.log.old');
      final parts = <String>[];
      if (await oldFile.exists()) {
        parts.add(await oldFile.readAsString());
      }
      if (await file.exists()) {
        parts.add(await file.readAsString());
      }
      return parts.join();
    } on Object catch (_) {
      return '';
    }
  }

  Future<int> getPersistentLogSize() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/logs/glibusta.log');
      final oldFile = File('${dir.path}/logs/glibusta.log.old');
      var total = 0;
      if (await file.exists()) {
        total += (await file.stat()).size;
      }
      if (await oldFile.exists()) {
        total += (await oldFile.stat()).size;
      }
      return total;
    } on Object catch (_) {
      return 0;
    }
  }

  Future<void> clearPersistentLog() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/logs/glibusta.log');
      final oldFile = File('${dir.path}/logs/glibusta.log.old');
      if (await file.exists()) {
        await file.writeAsString('');
      }
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    } on Object catch (_) {}
  }

  void clear() {
    _ringBuffer.clear();
  }

  void dispose() {
    unawaited(_controller.close());
    _listeners.clear();
  }
}

class _RingBuffer<T> {
  _RingBuffer(this._capacity);
  final int _capacity;
  late List<T?> _list = List<T?>.filled(_capacity, null);
  int _head = 0;
  int _count = 0;

  int get length => _count;
  bool get isFull => _count >= _capacity;

  void add(T item) {
    if (isFull) {
      _list[_head % _capacity] = item;
      _head++;
    } else {
      _list[_count] = item;
      _count++;
    }
  }

  List<T> toList() {
    if (_count < _capacity) {
      return List<T>.from(_list.sublist(0, _count));
    }
    final result = <T>[];
    for (var i = 0; i < _capacity; i++) {
      final idx = (_head + i) % _capacity;
      final item = _list[idx];
      if (item != null) result.add(item);
    }
    return result;
  }

  T? get last {
    if (_count == 0) return null;
    if (_count < _capacity) return _list[_count - 1];
    return _list[(_head - 1 + _capacity) % _capacity];
  }

  void clear() {
    _list = List<T?>.filled(_capacity, null);
    _head = 0;
    _count = 0;
  }
}

// --- Riverpod providers ---

final appLoggerProvider = Provider<AppLogger>((ref) {
  final logger = AppLogger();
  final eventBus = ref.watch(eventBusProvider);

  Logger.root.level = Level.ALL;
  final rootLogSubscription = Logger.root.onRecord.listen((record) {
    logger.log(
      record.level.name,
      record.message,
      loggerName: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  void publishSevereEvents(LogEntry entry) {
    if (entry.level == 'SEVERE' || entry.level == 'SHOUT') {
      eventBus.fire(
        ErrorOccurredEvent(
          source: entry.loggerName ?? 'unknown',
          message: entry.message,
          stackTrace: entry.stackTrace?.toString(),
        ),
      );
    }
  }

  logger.addListener(publishSevereEvents);

  ref.onDispose(() {
    logger.removeListener(publishSevereEvents);
    unawaited(rootLogSubscription.cancel());
    logger.dispose();
  });
  return logger;
});

final logEntriesProvider = Provider<List<LogEntry>>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return logger.entries;
});

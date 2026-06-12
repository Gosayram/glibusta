import 'dart:async';
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
  AppLogger({int bufferSize = 500}) : _ringBuffer = _RingBuffer<LogEntry>(bufferSize);

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
    if (level == 'SEVERE' || level == 'SHOUT') {
      unawaited(_persistError(entry));
    }
  }

  Future<void> _persistError(LogEntry entry) async {
    try {
      final line = entry.toLine();
      if (line.isNotEmpty) {
        final dir = await getApplicationSupportDirectory();
        final logDir = Directory('${dir.path}/logs');
        await logDir.create(recursive: true);
        final file = File('${logDir.path}/glibusta.log');
        final sink = file.openWrite(mode: FileMode.append);
        sink.writeln(line);
        await sink.flush();
        await sink.close();
      }
    } on Object catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final summary = entry.error != null
          ? '${entry.message} | ${entry.error}'
          : entry.message;
      await prefs.setString('last_error', summary);
    } on Object catch (_) {}
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
      if (!await file.exists()) return '';
      return await file.readAsString();
    } on Object catch (_) {
      return '';
    }
  }

  Future<int> getPersistentLogSize() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/logs/glibusta.log');
      if (!await file.exists()) return 0;
      final stat = await file.stat();
      return stat.size;
    } on Object catch (_) {
      return 0;
    }
  }

  Future<void> clearPersistentLog() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/logs/glibusta.log');
      if (await file.exists()) {
        await file.writeAsString('');
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
  final List<T> _list = [];
  int _start = 0;

  int get length => _list.length;
  bool get isFull => _list.length >= _capacity;

  void add(T item) {
    if (isFull) {
      _list[_start % _capacity] = item;
      _start++;
    } else {
      _list.add(item);
    }
  }

  List<T> toList() => List<T>.from(_list);
  T? get last => _list.isEmpty ? null : _list.last;
  void clear() {
    _list.clear();
    _start = 0;
  }
}

// --- Riverpod providers ---

final appLoggerProvider = Provider<AppLogger>((ref) {
  final logger = AppLogger(bufferSize: 1000);
  final eventBus = ref.watch(eventBusProvider);

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    logger.log(
      record.level.name,
      record.message,
      loggerName: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  logger.addListener((entry) {
    if (entry.level == 'SEVERE' || entry.level == 'SHOUT') {
      eventBus.fire(
        ErrorOccurredEvent(
          source: entry.loggerName ?? 'unknown',
          message: entry.message,
          stackTrace: entry.stackTrace?.toString(),
        ),
      );
    }
  });

  ref.onDispose(logger.dispose);
  return logger;
});

final logEntriesProvider = Provider<List<LogEntry>>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return logger.entries;
});

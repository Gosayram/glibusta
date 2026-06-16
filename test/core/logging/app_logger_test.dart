import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/logging/app_logger.dart';

void main() {
  group('LogEntry', () {
    test('stores all fields', () {
      final entry = LogEntry(
        level: 'INFO',
        message: 'test message',
        time: DateTime(2026),
        loggerName: 'TestLogger',
        error: 'some error',
        stackTrace: StackTrace.current,
      );
      expect(entry.level, 'INFO');
      expect(entry.message, 'test message');
      expect(entry.loggerName, 'TestLogger');
      expect(entry.error, 'some error');
      expect(entry.stackTrace, isNotNull);
    });

    test('nullable fields', () {
      final entry = LogEntry(
        level: 'FINE',
        message: 'msg',
        time: DateTime(2026),
      );
      expect(entry.loggerName, isNull);
      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
    });

    test('toLine formats correctly', () {
      final entry = LogEntry(
        level: 'INFO',
        message: 'hello',
        time: DateTime(2026, 1, 15, 10, 30),
        loggerName: 'MyLogger',
      );
      final line = entry.toLine();
      expect(line, contains('[2026-01-15'));
      expect(line, contains('INFO'));
      expect(line, contains('MyLogger'));
      expect(line, contains('hello'));
    });

    test('toLine includes error when present', () {
      final entry = LogEntry(
        level: 'SEVERE',
        message: 'crash',
        time: DateTime(2026),
        error: 'NullReferenceException',
      );
      final line = entry.toLine();
      expect(line, contains('ERROR: NullReferenceException'));
    });

    test('toLine excludes error when null', () {
      final entry = LogEntry(
        level: 'INFO',
        message: 'ok',
        time: DateTime(2026),
      );
      expect(entry.toLine(), isNot(contains('ERROR')));
    });

    test('toJson includes level, message, ts', () {
      final entry = LogEntry(
        level: 'WARNING',
        message: 'warn',
        time: DateTime(2026, 6, 13, 12),
      );
      final json = entry.toJson();
      expect(json['level'], 'WARNING');
      expect(json['message'], 'warn');
      expect(json.containsKey('ts'), isTrue);
    });

    test('toJson includes logger when present', () {
      final entry = LogEntry(
        level: 'INFO',
        message: 'test',
        time: DateTime(2026),
        loggerName: 'X',
      );
      expect(entry.toJson()['logger'], 'X');
    });

    test('toJson excludes logger when null', () {
      final entry = LogEntry(level: 'INFO', message: 'test', time: DateTime(2026));
      expect(entry.toJson().containsKey('logger'), isFalse);
    });

    test('toJson includes error when present', () {
      final entry = LogEntry(
        level: 'SEVERE',
        message: 'fail',
        time: DateTime(2026),
        error: 'oops',
      );
      expect(entry.toJson()['error'], 'oops');
    });
  });

  group('AppLogger (singleton)', () {
    late AppLogger logger;

    setUp(() {
      logger = AppLogger();
      logger.clear();
    });

    test('singleton returns same instance', () {
      final a = AppLogger();
      final b = AppLogger();
      expect(identical(a, b), isTrue);
    });

    test('log adds entry', () {
      logger.log('INFO', 'test message');
      expect(logger.entries.last.message, 'test message');
      expect(logger.entries.last.level, 'INFO');
    });

    test('log with loggerName', () {
      logger.log('INFO', 'test', loggerName: 'MyLogger');
      expect(logger.lastEntry?.loggerName, 'MyLogger');
    });

    test('log with error', () {
      logger.log('SEVERE', 'fail', error: 'exception');
      expect(logger.lastEntry?.error, 'exception');
    });

    test('convenience methods set correct level', () {
      logger.finest('a');
      expect(logger.lastEntry?.level, 'FINEST');
      logger.fine('b');
      expect(logger.lastEntry?.level, 'FINE');
      logger.info('c');
      expect(logger.lastEntry?.level, 'INFO');
      logger.warning('d');
      expect(logger.lastEntry?.level, 'WARNING');
      logger.severe('e');
      expect(logger.lastEntry?.level, 'SEVERE');
    });

    test('ring buffer maintains chronological order', () {
      for (var i = 0; i < 25; i++) {
        logger.log('INFO', 'item $i');
      }
      final messages = logger.entries.map((e) => e.message).toList();
      for (var i = 1; i < messages.length; i++) {
        final prev = int.parse(messages[i - 1].split(' ')[1]);
        final curr = int.parse(messages[i].split(' ')[1]);
        expect(curr, greaterThan(prev));
      }
    });

    test('ring buffer last is correct', () {
      for (var i = 0; i < 5; i++) {
        logger.log('INFO', 'item $i');
      }
      expect(logger.lastEntry?.message, 'item 4');
    });

    test('clear empties entries', () {
      logger.info('a');
      logger.info('b');
      logger.clear();
      expect(logger.entries, isEmpty);
      expect(logger.lastEntry, isNull);
    });

    test('stream emits log entries', () async {
      final entries = <LogEntry>[];
      logger.stream.listen(entries.add);
      logger.info('hello');
      await Future<void>.delayed(Duration.zero);
      expect(entries, isNotEmpty);
      expect(entries.last.message, 'hello');
    });

    test('addListener is called for each log', () {
      final received = <LogEntry>[];
      logger.addListener(received.add);
      logger.info('a');
      logger.warning('b');
      expect(received.length, 2);
      logger.removeListener(received.add);
    });

    test('removeListener stops receiving', () {
      final received = <LogEntry>[];
      logger.addListener(received.add);
      logger.info('a');
      logger.removeListener(received.add);
      logger.info('b');
      expect(received.length, 1);
    });

    test('exportAsText returns formatted lines', () {
      logger.clear();
      logger.info('line1');
      logger.warning('line2');
      final text = logger.exportAsText();
      expect(text, contains('line1'));
      expect(text, contains('line2'));
    });

    test('exportAsText empty when no entries', () {
      logger.clear();
      expect(logger.exportAsText(), '');
    });

    test('log with stackTrace', () {
      logger.log('INFO', 'trace test', stackTrace: StackTrace.current);
      expect(logger.lastEntry?.stackTrace, isNotNull);
    });

    test('warning with all params', () {
      logger.warning('warn', name: 'Logger', error: 'err');
      final entry = logger.lastEntry!;
      expect(entry.level, 'WARNING');
      expect(entry.loggerName, 'Logger');
      expect(entry.error, 'err');
    });

    test('severe with all params', () {
      logger.severe('fatal', name: 'Logger', error: 'crash');
      final entry = logger.lastEntry!;
      expect(entry.level, 'SEVERE');
      expect(entry.error, 'crash');
    });
  });

  group('LogLevel', () {
    test('has correct values', () {
      expect(LogLevel.values.length, 6);
      expect(LogLevel.values, contains(LogLevel.finest));
      expect(LogLevel.values, contains(LogLevel.fine));
      expect(LogLevel.values, contains(LogLevel.info));
      expect(LogLevel.values, contains(LogLevel.warning));
      expect(LogLevel.values, contains(LogLevel.severe));
      expect(LogLevel.values, contains(LogLevel.shout));
    });
  });
}

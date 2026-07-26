import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reading_break_reminder.dart';

void main() {
  group('ReadingBreakReminderController', () {
    late DateTime now;
    late _TimerQueue timers;
    late ReadingBreakReminderController controller;

    setUp(() {
      now = DateTime(2026);
      timers = _TimerQueue();
      controller = ReadingBreakReminderController(
        settings: const ReadingBreakReminderSettings(
          enabled: true,
          interval: ReadingBreakInterval.minutes15,
        ),
        now: () => now,
        timerFactory: timers.schedule,
      );
    });

    tearDown(() => controller.dispose());

    test('supports the documented selectable intervals', () {
      expect(
        ReadingBreakInterval.values.map((interval) => interval.duration),
        containsAll(<Duration>[
          const Duration(minutes: 15),
          const Duration(minutes: 20),
          const Duration(minutes: 30),
          const Duration(minutes: 60),
        ]),
      );
    });

    test('snooze emits another reminder only after the short interval', () {
      controller.start();
      timers.fireNext();
      expect(controller.state.isReminderDue, isTrue);

      controller.snooze();
      expect(controller.state.isReminderDue, isFalse);
      expect(timers.lastDuration, ReadingBreakReminderController.snoozeDuration);

      timers.fireNext();
      expect(controller.state.isReminderDue, isTrue);
    });

    test('pause preserves the remaining duration until resumed', () {
      controller.start();
      now = now.add(const Duration(minutes: 6));
      controller.pause();
      expect(timers.last.isActive, isFalse);

      now = now.add(const Duration(hours: 1));
      controller.resume();
      expect(timers.lastDuration, const Duration(minutes: 9));

      timers.fireNext();
      expect(controller.state.isReminderDue, isTrue);
    });

    test('disabling reminders cancels an active countdown', () {
      controller.start();
      controller.configure(const ReadingBreakReminderSettings());

      expect(timers.last.isActive, isFalse);
      expect(controller.state.settings.enabled, isFalse);
    });
  });

  testWidgets('lifecycle pauses and resumes without owning a modal', (tester) async {
    var reminders = 0;
    final timers = _TimerQueue();
    final controller = ReadingBreakReminderController(
      settings: const ReadingBreakReminderSettings(enabled: true),
      timerFactory: timers.schedule,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingBreakReminder(
          controller: controller,
          onReminderDue: () => ++reminders,
          child: const Scaffold(body: Text('Reader content')),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(timers.last.isActive, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(timers.last.isActive, isTrue);

    timers.fireNext();
    expect(reminders, 1);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Reader content'), findsOneWidget);
  });
}

final class _TimerQueue {
  final List<_TestTimer> _timers = <_TestTimer>[];

  _TestTimer get last => _timers.last;
  Duration get lastDuration => last.duration;

  Timer schedule(Duration duration, void Function() callback) {
    final timer = _TestTimer(duration, callback);
    _timers.add(timer);
    return timer;
  }

  void fireNext() {
    final timer = _timers.firstWhere((timer) => timer.isActive);
    timer.fire();
  }
}

final class _TestTimer implements Timer {
  _TestTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  var _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() => _isActive = false;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _callback();
  }
}

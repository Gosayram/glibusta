import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final readingBreakReminderControllerProvider = Provider.autoDispose<ReadingBreakReminderController>(
  (ref) {
    final controller = ReadingBreakReminderController();
    ref.onDispose(controller.dispose);
    return controller;
  },
);

/// The supported opt-in intervals between reading-break reminders.
enum ReadingBreakInterval {
  minutes15(Duration(minutes: 15)),
  minutes20(Duration(minutes: 20)),
  minutes30(Duration(minutes: 30)),
  minutes60(Duration(minutes: 60));

  const ReadingBreakInterval(this.duration);

  /// The amount of uninterrupted reading before a reminder is emitted.
  final Duration duration;
}

/// User-controlled configuration for [ReadingBreakReminderController].
@immutable
final class ReadingBreakReminderSettings {
  const ReadingBreakReminderSettings({
    this.enabled = false,
    this.interval = ReadingBreakInterval.minutes20,
  });

  /// Whether reminders are enabled for the current reading session.
  final bool enabled;

  /// The preferred uninterrupted-reading interval.
  final ReadingBreakInterval interval;

  ReadingBreakReminderSettings copyWith({
    bool? enabled,
    ReadingBreakInterval? interval,
  }) {
    return ReadingBreakReminderSettings(
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
    );
  }
}

/// Immutable state exposed by [ReadingBreakReminderController].
@immutable
final class ReadingBreakReminderState {
  const ReadingBreakReminderState({
    required this.settings,
    required this.isPaused,
    required this.isReminderDue,
  });

  final ReadingBreakReminderSettings settings;
  final bool isPaused;
  final bool isReminderDue;
}

typedef ReadingBreakTimerFactory = Timer Function(Duration, void Function());

/// Tracks reading time and emits a state change when an opt-in break is due.
///
/// This controller deliberately owns no dialog or snackbar. A host chooses a
/// suitable non-blocking presentation through [ReadingBreakReminder.onReminderDue].
final class ReadingBreakReminderController extends ChangeNotifier {
  ReadingBreakReminderController({
    ReadingBreakReminderSettings settings = const ReadingBreakReminderSettings(),
    DateTime Function()? now,
    ReadingBreakTimerFactory? timerFactory,
  }) : _settings = settings,
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new;

  static const snoozeDuration = Duration(minutes: 5);

  final DateTime Function() _now;
  final ReadingBreakTimerFactory _timerFactory;
  Timer? _timer;
  DateTime? _deadline;
  Duration? _remaining;
  ReadingBreakReminderSettings _settings;
  var _isPaused = false;
  var _isReminderDue = false;

  ReadingBreakReminderState get state => ReadingBreakReminderState(
    settings: _settings,
    isPaused: _isPaused,
    isReminderDue: _isReminderDue,
  );

  /// Applies new settings and restarts the countdown when enabled.
  void configure(ReadingBreakReminderSettings settings) {
    _settings = settings;
    _isReminderDue = false;
    _remaining = settings.enabled ? settings.interval.duration : null;
    _cancelTimer();
    if (settings.enabled) {
      _isPaused = false;
      _schedule(_remaining!);
    } else {
      _isPaused = false;
    }
    notifyListeners();
  }

  /// Starts the configured interval when reminders are enabled.
  void start() {
    if (!_settings.enabled || _isReminderDue || _timer != null) return;
    _isPaused = false;
    _schedule(_remaining ?? _settings.interval.duration);
    notifyListeners();
  }

  /// Preserves the remaining duration without emitting reminders in background.
  void pause() {
    if (!_settings.enabled || _isPaused || _isReminderDue) return;
    final deadline = _deadline;
    _remaining = deadline == null
        ? _settings.interval.duration
        : _boundedRemaining(deadline.difference(_now()));
    _cancelTimer();
    _isPaused = true;
    notifyListeners();
  }

  /// Continues a countdown paused by the app lifecycle.
  void resume() {
    if (!_settings.enabled || !_isPaused || _isReminderDue) return;
    _isPaused = false;
    _schedule(_remaining ?? _settings.interval.duration);
    notifyListeners();
  }

  /// Clears a visible reminder and starts the normal interval again.
  void dismiss() {
    if (!_isReminderDue) return;
    _isReminderDue = false;
    _isPaused = false;
    _schedule(_settings.interval.duration);
    notifyListeners();
  }

  /// Clears a visible reminder and schedules a short opt-in snooze.
  void snooze() {
    if (!_isReminderDue) return;
    _isReminderDue = false;
    _isPaused = false;
    _schedule(snoozeDuration);
    notifyListeners();
  }

  void _schedule(Duration duration) {
    _remaining = duration;
    _deadline = _now().add(duration);
    _timer = _timerFactory(duration, () {
      _timer = null;
      _deadline = null;
      _remaining = null;
      if (!_settings.enabled || _isPaused) return;
      _isReminderDue = true;
      notifyListeners();
    });
  }

  Duration _boundedRemaining(Duration duration) {
    if (duration.isNegative) return Duration.zero;
    if (duration > _settings.interval.duration) return _settings.interval.duration;
    return duration;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }
}

/// Connects a reminder controller to Flutter lifecycle events.
///
/// It provides no visual surface itself, so hosts remain free to present a
/// snackbar, banner, or another non-blocking reader-specific affordance.
final class ReadingBreakReminder extends StatefulWidget {
  const ReadingBreakReminder({
    required this.controller,
    required this.child,
    required this.onReminderDue,
    super.key,
  });

  final ReadingBreakReminderController controller;
  final Widget child;
  final VoidCallback onReminderDue;

  @override
  State<ReadingBreakReminder> createState() => _ReadingBreakReminderState();
}

final class _ReadingBreakReminderState extends State<ReadingBreakReminder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    widget.controller.start();
  }

  @override
  void didUpdateWidget(covariant ReadingBreakReminder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
    widget.controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.controller.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        widget.controller.pause();
    }
  }

  void _onControllerChanged() {
    if (widget.controller.state.isReminderDue) widget.onReminderDue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:async';

import 'package:flutter/material.dart';

class MinuteClock extends StatefulWidget {
  const MinuteClock({super.key, this.style, this.builder});

  final TextStyle? style;
  final Widget Function(BuildContext context, String time)? builder;

  @override
  State<MinuteClock> createState() => _MinuteClockState();
}

class _MinuteClockState extends State<MinuteClock> {
  Timer? _timer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _scheduleNextUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    _time = '$hour:$minute';
  }

  void _scheduleNextUpdate() {
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final duration = nextMinute.difference(now);
    _timer = Timer(duration, () {
      if (mounted) {
        _updateTime();
        setState(() {});
        _scheduleNextUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return widget.builder!(context, _time);
    }
    return Text(
      _time,
      style: widget.style,
    );
  }
}

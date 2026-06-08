import 'package:flutter/widgets.dart';

class LifecycleService {
  VoidCallback? _onPause;

  void setOnPauseCallback(VoidCallback callback) {
    _onPause = callback;
  }

  void handlePause() {
    _onPause?.call();
  }
}
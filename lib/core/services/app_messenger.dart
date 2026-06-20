import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../theme/app_colors.dart';
import '../theme/app_duration.dart';

abstract interface class AppMessenger {
  void showSuccess(String message);
  void showError(String message);
  void showInfo(String message);
  void showUndo(String message, Future<void> Function() onUndo, {String undoLabel = 'Отменить'});
}

class ScaffoldMessengerService implements AppMessenger {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  ScaffoldMessengerService(this._scaffoldMessengerKey);

  ScaffoldMessengerState? get _messenger => _scaffoldMessengerKey.currentState;

  @override
  void showSuccess(String message) {
    unawaited(SmartDialog.showToast(
      message,
      displayDuration: AppDuration.snackbarShort,
    ));
  }

  @override
  void showError(String message) {
    unawaited(SmartDialog.showToast(
      message,
      displayDuration: AppDuration.snackbarNormal,
    ));
  }

  @override
  void showInfo(String message) {
    unawaited(SmartDialog.showToast(message));
  }

  @override
  void showUndo(String message, Future<void> Function() onUndo, {String undoLabel = 'Отменить'}) {
    unawaited(SmartDialog.showToast(message));
  }
}

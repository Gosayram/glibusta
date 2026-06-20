import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../theme/app_duration.dart';

abstract interface class AppMessenger {
  void showSuccess(String message);
  void showError(String message);
  void showInfo(String message);
  void showUndo(String message, Future<void> Function() onUndo, {String undoLabel = 'Отменить'});
}

class ScaffoldMessengerService implements AppMessenger {
  ScaffoldMessengerService();

  @override
  void showSuccess(String message) {
    unawaited(
      SmartDialog.showToast(
        message,
        displayTime: AppDuration.snackbarShort,
      ),
    );
  }

  @override
  void showError(String message) {
    unawaited(
      SmartDialog.showToast(
        message,
        displayTime: AppDuration.snackbarNormal,
      ),
    );
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

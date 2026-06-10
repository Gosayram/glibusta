import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_duration.dart';

abstract interface class AppMessenger {
  void showSuccess(String message);
  void showError(String message);
  void showInfo(String message);
  void showUndo(String message, VoidCallback onUndo);
}

class ScaffoldMessengerService implements AppMessenger {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  ScaffoldMessengerService(this._scaffoldMessengerKey);

  ScaffoldMessengerState? get _messenger => _scaffoldMessengerKey.currentState;

  @override
  void showSuccess(String message) {
    _messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: AppDuration.snackbarShort,
      ),
    );
  }

  @override
  void showError(String message) {
    _messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: AppDuration.snackbarNormal,
      ),
    );
  }

  @override
  void showInfo(String message) {
    _messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void showUndo(String message, VoidCallback onUndo) {
    _messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: onUndo,
        ),
      ),
    );
  }
}

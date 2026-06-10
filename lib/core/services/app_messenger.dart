import 'package:flutter/material.dart';

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
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void showError(String message) {
    _messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
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

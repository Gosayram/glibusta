import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class AppToast {
  static void show(
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    SmartDialog.showToast(
      '',
      builder: (context) {
        final theme = Theme.of(context);
        final (icon, color) = _iconAndColor(type, theme);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      displayTime: duration,
    );
  }

  static void showSuccess(String message) {
    show(message, type: ToastType.success);
  }

  static void showError(String message) {
    show(message, type: ToastType.error, duration: const Duration(seconds: 4));
  }

  static void showWarning(String message) {
    show(message, type: ToastType.warning);
  }

  static (IconData, Color) _iconAndColor(ToastType type, ThemeData theme) {
    switch (type) {
      case ToastType.success:
        return (Icons.check_circle_outline, Colors.green);
      case ToastType.error:
        return (Icons.error_outline, theme.colorScheme.error);
      case ToastType.warning:
        return (Icons.warning_amber_outlined, Colors.orange);
      case ToastType.info:
        return (Icons.info_outline, theme.colorScheme.primary);
    }
  }
}

enum ToastType { success, error, warning, info }

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_duration.dart';

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String? details;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
              semanticsLabel: message,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: const Text('Повторить'),
                  ),
                if (details != null)
                  OutlinedButton(
                    onPressed: () {
                      unawaited(Clipboard.setData(ClipboardData(text: details!)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ошибка скопирована'),
                          duration: AppDuration.snackbarShort,
                        ),
                      );
                    },
                    child: const Text('Скопировать ошибку'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

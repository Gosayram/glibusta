import 'package:flutter/material.dart';

import '../../core/platform/adaptive_context.dart';

/// Shows a bottom sheet on compact screens and a dialog on medium/expanded.
///
/// Usage:
/// ```dart
/// showAdaptivePanel<void>(
///   context: context,
///   child: const ReaderSettingsPanel(),
/// );
/// ```
Future<T?> showAdaptivePanel<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
      builder: (_) => child,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 720,
        ),
        child: child,
      ),
    ),
  );
}

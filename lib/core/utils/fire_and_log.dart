import 'dart:async';

import '../logging/app_logger.dart';

void fireAndLog(
  Future<void> Function() operation, {
  String? name,
  String? context,
}) {
  unawaited(
    _runAndLog(operation, name: name, context: context),
  );
}

Future<void> _runAndLog(
  Future<void> Function() operation, {
  String? name,
  String? context,
}) async {
  try {
    await operation();
  } on Object catch (e, st) {
    AppLogger().warning(
      context != null ? '$context: $e' : '$e',
      name: name ?? 'Background',
      error: e,
      st: st,
    );
  }
}

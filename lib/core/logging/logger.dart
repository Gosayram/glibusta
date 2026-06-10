import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final loggerProvider = Provider<Logger>((ref) {
  final log = Logger('Glibusta');
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
    }
  });
  return log;
});

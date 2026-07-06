import 'dart:async';

import 'package:workmanager/workmanager.dart';

import '../logging/app_logger.dart';

/// STR-4.2: Self-written sync via workmanager.
/// Periodically syncs reading progress, bookmarks, and notes to a remote server.
class SyncService {
  static const String _taskName = 'glibusta-sync';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await Workmanager().initialize(
      callbackDispatcher,
    );
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    AppLogger().info('SyncService initialized', name: 'Sync');
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }

  /// Manual sync trigger (from UI button).
  static Future<void> syncNow() async {
    AppLogger().info('Manual sync triggered', name: 'Sync');
    // TODO: implement actual sync logic — upload diff to server
  }
}

/// STR-4.2: Background task callback for workmanager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger().info('Background sync task: $task', name: 'Sync');
    // TODO: sync reading progress, bookmarks, notes to server
    return true;
  });
}

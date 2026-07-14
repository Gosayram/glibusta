import 'dart:async';

import 'package:powersync/powersync.dart';
import 'package:workmanager/workmanager.dart';

import '../logging/app_logger.dart';
import '../sync/powersync_adapter.dart';
import '../sync/powersync_connector.dart';
import '../sync/sync_bridge.dart';

/// STR-4: Orchestrates sync between Drift, PowerSync, and Cloud.
///
/// The static [initialize] sets up the background workmanager task.
/// Connect via [connect] to enable PowerSync live sync.
class SyncService {
  static const String _taskName = 'glibusta-sync';
  static bool _initialized = false;

  final PowerSyncAdapter _adapter;
  final GlibustaSyncConnector _connector;
  final SyncBridge _bridge;

  SyncService({
    required PowerSyncAdapter powersyncAdapter,
    required GlibustaSyncConnector connector,
    required SyncBridge bridge,
  }) : _adapter = powersyncAdapter,
       _connector = connector,
       _bridge = bridge;

  // ---------------------------------------------------------------------------
  // Static life-cycle (workmanager)
  // ---------------------------------------------------------------------------

  static Future<void> initialize() async {
    if (_initialized) return;

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
    _initialized = true;
    AppLogger().info('SyncService workmanager initialized', name: 'Sync');
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }

  // ---------------------------------------------------------------------------
  // PowerSync life-cycle
  // ---------------------------------------------------------------------------

  /// Connect to the PowerSync service.
  Future<void> connect() => _adapter.connect(_connector);

  /// Disconnect from the PowerSync service.
  Future<void> disconnect() => _adapter.disconnect();

  /// Disconnect and clear synced data (logout).
  Future<void> disconnectAndClear() => _adapter.disconnectAndClear();

  /// Close the PowerSync database entirely.
  Future<void> close() => _adapter.close();

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  Stream<SyncStatus> get statusStream => _adapter.statusStream;
  SyncStatus? get currentStatus => _adapter.currentStatus;
  bool get isConnected => _adapter.isConnected;

  // ---------------------------------------------------------------------------
  // Bridge helpers
  // ---------------------------------------------------------------------------

  SyncBridge get bridge => _bridge;

  // ---------------------------------------------------------------------------
  // Manual sync
  // ---------------------------------------------------------------------------

  /// Manual sync trigger (from UI button).
  Future<void> syncNow() async {
    AppLogger().info('Manual sync triggered', name: 'Sync');
    if (!_connector.isConfigured) {
      AppLogger().warning(
        'SyncService: connector not configured, skipping sync.',
        name: 'Sync',
      );
      return;
    }
    if (!_adapter.isConnected) {
      await connect();
    }
  }
}

/// STR-4.2: Background task callback for workmanager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger().info('Background sync task: $task', name: 'Sync');
    return true;
  });
}

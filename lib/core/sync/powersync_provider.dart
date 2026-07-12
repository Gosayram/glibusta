import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync_service.dart';
import 'powersync_adapter.dart';
import 'powersync_connector.dart';
import 'sync_bridge.dart';

/// Singleton PowerSync adapter.
final powersyncAdapterProvider = Provider<PowerSyncAdapter>((ref) {
  final adapter = PowerSyncAdapter();
  ref.onDispose(() => adapter.close());
  return adapter;
});

/// Configurable backend connector — override via provider override in tests
/// or to supply production credentials.
final powersyncConnectorProvider = Provider<GlibustaSyncConnector>(
  (ref) => GlibustaSyncConnector(),
);

/// Bridge that mirrors Drift writes into PowerSync.
final syncBridgeProvider = Provider<SyncBridge>((ref) {
  final adapter = ref.watch(powersyncAdapterProvider);
  return SyncBridge(adapter);
});

/// Sync service that orchestrates Drift <-> PowerSync <-> Cloud.
final syncServiceProvider = Provider<SyncService>((ref) {
  final adapter = ref.watch(powersyncAdapterProvider);
  final connector = ref.watch(powersyncConnectorProvider);
  final bridge = ref.watch(syncBridgeProvider);
  return SyncService(
    powersyncAdapter: adapter,
    connector: connector,
    bridge: bridge,
  );
});

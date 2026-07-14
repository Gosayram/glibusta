import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import '../logging/app_logger.dart';
import 'powersync_schema.dart';

/// Manages the PowerSync database lifecycle.
///
/// Wraps [PowerSyncDatabase] with the app schema and provides
/// connect/disconnect/status helpers.
class PowerSyncAdapter {
  PowerSyncDatabase? _db;
  Future<PowerSyncDatabase>? _initializing;
  bool _connected = false;

  PowerSyncDatabase? get database => _db;
  bool get isConnected => _connected;

  /// Initialize the PowerSync database file.
  Future<PowerSyncDatabase> init() async {
    final database = _db;
    if (database != null) return database;

    final initializing = _initializing;
    if (initializing != null) return initializing;

    final future = _createDatabase();
    _initializing = future;
    try {
      return await future;
    } finally {
      if (identical(_initializing, future)) {
        _initializing = null;
      }
    }
  }

  Future<PowerSyncDatabase> _createDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final databaseDir = Directory(p.join(dir.path, 'glibusta'));
    await databaseDir.create(recursive: true);
    final dbPath = p.join(databaseDir.path, 'glibusta_sync.db');
    final database = PowerSyncDatabase(
      schema: PowerSyncSchemas.schema,
      path: dbPath,
    );

    await database.initialize();
    _db = database;
    AppLogger().info('PowerSync database initialized', name: 'PowerSync');
    return database;
  }

  /// Connect to the PowerSync service using the given connector.
  Future<void> connect(PowerSyncBackendConnector connector) async {
    final db = await init();
    if (_connected) return;

    await db.connect(connector: connector);
    _connected = true;
    AppLogger().info(
      'PowerSync connected — endpoint: ${await _resolveEndpoint(connector)}',
      name: 'PowerSync',
    );
  }

  /// Disconnect from the PowerSync service.
  Future<void> disconnect() async {
    if (_db == null || !_connected) return;
    await _db!.disconnect();
    _connected = false;
    AppLogger().info('PowerSync disconnected', name: 'PowerSync');
  }

  /// Disconnect and clear all synced data (e.g. on logout).
  Future<void> disconnectAndClear() async {
    if (_db == null) return;
    await _db!.disconnectAndClear();
    _connected = false;
    AppLogger().info('PowerSync disconnected and cleared', name: 'PowerSync');
  }

  /// Close the database entirely.
  Future<void> close() async {
    final initializing = _initializing;
    if (initializing != null) {
      await initializing;
    }
    await disconnect();
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    AppLogger().info('PowerSync database closed', name: 'PowerSync');
  }

  Stream<SyncStatus> get statusStream => _db?.statusStream ?? const Stream.empty();
  SyncStatus? get currentStatus => _db?.currentStatus;

  Future<String?> _resolveEndpoint(PowerSyncBackendConnector connector) async {
    try {
      final creds = await connector.fetchCredentials();
      return creds?.endpoint;
    } on Object catch (_) {
      return null;
    }
  }
}

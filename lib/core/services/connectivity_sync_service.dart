import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';

enum SyncNetworkStatus { wifiOnly, anyNetwork, disabled }

class ConnectivitySyncService {
  ConnectivitySyncService(this._preference);

  final SyncNetworkStatus _preference;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _syncAllowed = false;

  bool get isSyncAllowed => _syncAllowed;

  void startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluate(results);
    });
    _connectivity.checkConnectivity().then(_evaluate);
  }

  void _evaluate(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final hasWifi = results.any((r) => r == ConnectivityResult.wifi);

    switch (_preference) {
      case SyncNetworkStatus.wifiOnly:
        _syncAllowed = hasWifi;
      case SyncNetworkStatus.anyNetwork:
        _syncAllowed = hasConnection;
      case SyncNetworkStatus.disabled:
        _syncAllowed = false;
    }

    AppLogger.debug('Connectivity changed: $results → syncAllowed=$_syncAllowed');
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final syncNetworkStatusProvider = Provider<SyncNetworkStatus>((ref) {
  return SyncNetworkStatus.wifiOnly;
});

final connectivitySyncServiceProvider = Provider<ConnectivitySyncService>((ref) {
  final preference = ref.watch(syncNetworkStatusProvider);
  final service = ConnectivitySyncService(preference);
  service.startListening();
  ref.onDispose(service.dispose);
  return service;
});

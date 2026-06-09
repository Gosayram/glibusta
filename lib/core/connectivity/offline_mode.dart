import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';

enum ConnectivityState { online, offline, unknown }

class OfflineModeService {
  OfflineModeService(this._logger) {
    unawaited(_init());
  }

  final AppLogger _logger;
  final _controller = StreamController<ConnectivityState>.broadcast();
  ConnectivityState _state = ConnectivityState.unknown;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final List<void Function(ConnectivityState)> _listeners = [];

  ConnectivityState get state => _state;
  bool get isOnline => _state == ConnectivityState.online;
  bool get isOffline => _state == ConnectivityState.offline;
  Stream<ConnectivityState> get stream => _controller.stream;

  Future<void> _init() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateState(results);
    } on Object catch (e) {
      _logger.warning('Connectivity check failed: $e', name: 'OfflineMode');
    }

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateState(results);
    });
  }

  void _updateState(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final newState = hasConnection ? ConnectivityState.online : ConnectivityState.offline;

    if (newState != _state) {
      _state = newState;
      _logger.info(
        'Connectivity changed: ${newState.name}',
        name: 'OfflineMode',
      );
      _controller.add(newState);
      for (final listener in _listeners) {
        listener(newState);
      }
    }
  }

  void addListener(void Function(ConnectivityState) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(ConnectivityState) listener) {
    _listeners.remove(listener);
  }

  Future<void> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (isOnline) return;
    final completer = Completer<void>();
    Timer? timer;

    final sub = stream.listen((state) {
      if (state == ConnectivityState.online && !completer.isCompleted) {
        timer?.cancel();
        completer.complete();
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    await sub.cancel();
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_controller.close());
    _listeners.clear();
  }
}

// --- Riverpod providers ---

final offlineModeServiceProvider = Provider<OfflineModeService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  final service = OfflineModeService(logger);
  ref.onDispose(service.dispose);
  return service;
});

final connectivityStateProvider = Provider<ConnectivityState>((ref) {
  final service = ref.watch(offlineModeServiceProvider);
  return service.state;
});

final isOnlineProvider = Provider<bool>((ref) {
  final state = ref.watch(connectivityStateProvider);
  return state == ConnectivityState.online;
});

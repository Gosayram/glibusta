import 'dart:async';
import 'dart:io' as io;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

part 'offline_mode.g.dart';

// --- Network state models ---

enum NetworkKind { unknown, offline, wifi, mobile, ethernet, other }

final class NetworkState {
  const NetworkState({required this.kind, required this.isMetered});

  final NetworkKind kind;
  final bool isMetered;

  bool get canDownload => kind != NetworkKind.offline;
  bool get shouldAskBeforeLargeDownload => isMetered;
}

NetworkState mapConnectivity(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.none)) {
    return const NetworkState(kind: NetworkKind.offline, isMetered: false);
  }
  if (results.contains(ConnectivityResult.wifi)) {
    return const NetworkState(kind: NetworkKind.wifi, isMetered: false);
  }
  if (results.contains(ConnectivityResult.ethernet)) {
    return const NetworkState(kind: NetworkKind.ethernet, isMetered: false);
  }
  if (results.contains(ConnectivityResult.mobile)) {
    return const NetworkState(kind: NetworkKind.mobile, isMetered: true);
  }
  return const NetworkState(kind: NetworkKind.other, isMetered: true);
}

// --- Download policy ---

const _kAllowMobileDownloads = 'allow_mobile_downloads';
const _kAutoResumeOnWifi = 'auto_resume_on_wifi';

class DownloadPolicyPersistence {
  DownloadPolicyPersistence(this._prefs);

  final SharedPreferences _prefs;

  bool get allowMobileDownloads => _prefs.getBool(_kAllowMobileDownloads) ?? false;
  set allowMobileDownloads(bool v) => unawaited(_prefs.setBool(_kAllowMobileDownloads, v));

  bool get autoResumeOnWifi => _prefs.getBool(_kAutoResumeOnWifi) ?? true;
  set autoResumeOnWifi(bool v) => unawaited(_prefs.setBool(_kAutoResumeOnWifi, v));
}

@Riverpod(keepAlive: true)
Future<DownloadPolicyPersistence> downloadPolicyPersistence(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return DownloadPolicyPersistence(prefs);
}

@Riverpod(keepAlive: true)
class AllowMobileDownloadsNotifier extends _$AllowMobileDownloadsNotifier {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    final p = await ref.read(downloadPolicyPersistenceProvider.future);
    state = p.allowMobileDownloads;
  }

  Future<void> update(bool value) async {
    state = value;
    final p = await ref.read(downloadPolicyPersistenceProvider.future);
    p.allowMobileDownloads = value;
  }
}

@Riverpod(keepAlive: true)
class AutoResumeOnWifiNotifier extends _$AutoResumeOnWifiNotifier {
  @override
  bool build() {
    unawaited(_load());
    return true;
  }

  Future<void> _load() async {
    final p = await ref.read(downloadPolicyPersistenceProvider.future);
    state = p.autoResumeOnWifi;
  }

  Future<void> update(bool value) async {
    state = value;
    final p = await ref.read(downloadPolicyPersistenceProvider.future);
    p.autoResumeOnWifi = value;
  }
}

bool canStartDownload({
  required NetworkState network,
  required bool allowMobileDownloads,
}) {
  if (!network.canDownload) return false;
  if (network.isMetered && !allowMobileDownloads) return false;
  return true;
}

// --- Stream provider ---

@Riverpod(keepAlive: true)
Stream<NetworkState> networkState(Ref ref) {
  return Connectivity().onConnectivityChanged.map(mapConnectivity);
}

@Riverpod(keepAlive: true)
Future<NetworkState> currentNetwork(Ref ref) async {
  final results = await Connectivity().checkConnectivity();
  return mapConnectivity(results);
}

// --- Legacy OfflineModeService (kept for backward compatibility) ---

class OfflineModeService {
  OfflineModeService(this._logger) {
    unawaited(_init());
  }

  final AppLogger _logger;
  final _controller = StreamController<NetworkState>.broadcast();
  NetworkState _state = const NetworkState(kind: NetworkKind.unknown, isMetered: false);
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkState get state => _state;
  bool get isOnline => _state.kind != NetworkKind.offline;
  bool get isOffline => _state.kind == NetworkKind.offline;
  Stream<NetworkState> get stream => _controller.stream;

  Future<void> _init() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateState(results);
    } on Object catch (e) {
      _logger.warning('Connectivity check failed: $e', name: 'OfflineMode');
    }

    _subscription = Connectivity().onConnectivityChanged.listen(_updateState);
  }

  void _updateState(List<ConnectivityResult> results) {
    final newState = mapConnectivity(results);
    if (newState.kind != _state.kind) {
      _state = newState;
      _logger.info('Connectivity changed: ${newState.kind.name}', name: 'OfflineMode');
      _controller.add(newState);
    }
  }

  Future<void> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (isOnline) return;
    final completer = Completer<void>();
    Timer? timer;

    final sub = stream.listen((state) {
      if (state.kind != NetworkKind.offline && !completer.isCompleted) {
        timer?.cancel();
        completer.complete();
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    await sub.cancel();
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_controller.close());
  }

  static Future<bool> probeServer(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: {'User-Agent': 'Glibusta/0.1.0'},
      ),
    );
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return io.HttpClient()
        ..badCertificateCallback = (io.X509Certificate cert, String host, int port) => true;
    };
    try {
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final response = await dio.head<dynamic>('$normalizedBase/opds/');
      return response.statusCode != null;
    } on Object catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }
}

// --- Legacy providers (kept for backward compatibility) ---

final offlineModeServiceProvider = Provider<OfflineModeService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  final service = OfflineModeService(logger);
  ref.onDispose(service.dispose);
  return service;
});

final connectivityStateProvider = StreamProvider<NetworkState>((ref) {
  final service = ref.watch(offlineModeServiceProvider);
  return service.stream;
});

final isOnlineProvider = Provider<bool>((ref) {
  final asyncState = ref.watch(connectivityStateProvider);
  final state = asyncState.value;
  return state != null && state.kind != NetworkKind.offline;
});

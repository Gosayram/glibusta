import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

@riverpod
Future<NetworkState> currentNetwork(Ref ref) async {
  final results = await Connectivity().checkConnectivity();
  return mapConnectivity(results);
}

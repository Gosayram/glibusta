import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/connectivity/offline_mode.dart';

void main() {
  group('NetworkState', () {
    test('wifi is not metered', () {
      const state = NetworkState(kind: NetworkKind.wifi, isMetered: false);
      expect(state.canDownload, isTrue);
      expect(state.shouldAskBeforeLargeDownload, isFalse);
    });

    test('mobile is metered', () {
      const state = NetworkState(kind: NetworkKind.mobile, isMetered: true);
      expect(state.canDownload, isTrue);
      expect(state.shouldAskBeforeLargeDownload, isTrue);
    });

    test('offline cannot download', () {
      const state = NetworkState(kind: NetworkKind.offline, isMetered: false);
      expect(state.canDownload, isFalse);
      expect(state.shouldAskBeforeLargeDownload, isFalse);
    });

    test('ethernet is not metered', () {
      const state = NetworkState(kind: NetworkKind.ethernet, isMetered: false);
      expect(state.canDownload, isTrue);
      expect(state.shouldAskBeforeLargeDownload, isFalse);
    });
  });

  group('mapConnectivity', () {
    test('none → offline', () {
      final state = mapConnectivity([ConnectivityResult.none]);
      expect(state.kind, NetworkKind.offline);
      expect(state.isMetered, isFalse);
    });

    test('wifi → wifi', () {
      final state = mapConnectivity([ConnectivityResult.wifi]);
      expect(state.kind, NetworkKind.wifi);
      expect(state.isMetered, isFalse);
    });

    test('ethernet → ethernet', () {
      final state = mapConnectivity([ConnectivityResult.ethernet]);
      expect(state.kind, NetworkKind.ethernet);
      expect(state.isMetered, isFalse);
    });

    test('mobile → mobile', () {
      final state = mapConnectivity([ConnectivityResult.mobile]);
      expect(state.kind, NetworkKind.mobile);
      expect(state.isMetered, isTrue);
    });

    test('bluetooth → other', () {
      final state = mapConnectivity([ConnectivityResult.bluetooth]);
      expect(state.kind, NetworkKind.other);
      expect(state.isMetered, isTrue);
    });

    test('wifi takes priority over mobile', () {
      final state = mapConnectivity([
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
      ]);
      expect(state.kind, NetworkKind.wifi);
      expect(state.isMetered, isFalse);
    });

    test('empty list → other', () {
      final state = mapConnectivity([]);
      expect(state.kind, NetworkKind.other);
      expect(state.isMetered, isTrue);
    });
  });

  group('canStartDownload', () {
    test('wifi always allowed', () {
      const wifi = NetworkState(kind: NetworkKind.wifi, isMetered: false);
      expect(canStartDownload(network: wifi, allowMobileDownloads: false), isTrue);
      expect(canStartDownload(network: wifi, allowMobileDownloads: true), isTrue);
    });

    test('offline never allowed', () {
      const offline = NetworkState(kind: NetworkKind.offline, isMetered: false);
      expect(canStartDownload(network: offline, allowMobileDownloads: true), isFalse);
    });

    test('mobile requires allowMobileDownloads', () {
      const mobile = NetworkState(kind: NetworkKind.mobile, isMetered: true);
      expect(canStartDownload(network: mobile, allowMobileDownloads: false), isFalse);
      expect(canStartDownload(network: mobile, allowMobileDownloads: true), isTrue);
    });

    test('ethernet always allowed', () {
      const eth = NetworkState(kind: NetworkKind.ethernet, isMetered: false);
      expect(canStartDownload(network: eth, allowMobileDownloads: false), isTrue);
    });
  });
}

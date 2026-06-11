import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/connectivity/offline_mode.dart';

void main() {
  group('OfflineModeService', () {
    test('NetworkKind enum values exist', () {
      expect(NetworkKind.values, contains(NetworkKind.unknown));
      expect(NetworkKind.values, contains(NetworkKind.offline));
      expect(NetworkKind.values, contains(NetworkKind.wifi));
      expect(NetworkKind.values, contains(NetworkKind.mobile));
      expect(NetworkKind.values, contains(NetworkKind.ethernet));
      expect(NetworkKind.values, contains(NetworkKind.other));
    });

    test('NetworkState helpers', () {
      const offline = NetworkState(kind: NetworkKind.offline, isMetered: false);
      expect(offline.canDownload, isFalse);

      const wifi = NetworkState(kind: NetworkKind.wifi, isMetered: false);
      expect(wifi.canDownload, isTrue);
      expect(wifi.shouldAskBeforeLargeDownload, isFalse);

      const mobile = NetworkState(kind: NetworkKind.mobile, isMetered: true);
      expect(mobile.canDownload, isTrue);
      expect(mobile.shouldAskBeforeLargeDownload, isTrue);
    });

    group('probeServer', () {
      test('returns bool for unreachable server', () async {
        final result = await OfflineModeService.probeServer(
          'http://192.0.2.1',
          timeout: const Duration(seconds: 2),
        );
        expect(result, isA<bool>());
        expect(result, isFalse);
      });

      test('returns bool for invalid URL', () async {
        final result = await OfflineModeService.probeServer(
          'https://this-does-not-exist.invalid',
          timeout: const Duration(seconds: 2),
        );
        expect(result, isA<bool>());
        expect(result, isFalse);
      });
    });
  });
}

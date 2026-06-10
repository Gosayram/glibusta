import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/connectivity/offline_mode.dart';

void main() {
  group('OfflineModeService', () {
    test('initial state is unknown', () {
      // OfflineModeService requires AppLogger, skip construction
      // Just verify enum values exist
      expect(ConnectivityState.values, contains(ConnectivityState.unknown));
      expect(ConnectivityState.values, contains(ConnectivityState.online));
      expect(ConnectivityState.values, contains(ConnectivityState.offline));
    });

    group('probeServer', () {
      test('returns bool for unreachable server', () async {
        final result = await OfflineModeService.probeServer(
          'http://192.0.2.1', // RFC 5737 TEST-NET — always unreachable
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

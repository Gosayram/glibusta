import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/services/conflict_resolver.dart';

void main() {
  group('ConflictResolver', () {
    test('newer local record wins', () {
      final local = SyncRecord(
        id: '1',
        updatedAt: DateTime(2025, 1, 2),
        data: 'local',
      );
      final remote = SyncRecord(
        id: '1',
        updatedAt: DateTime(2025),
        data: 'remote',
      );
      final result = ConflictResolver.resolve(local, remote);
      expect(result.data, 'local');
    });

    test('newer remote record wins', () {
      final local = SyncRecord(
        id: '1',
        updatedAt: DateTime(2025),
        data: 'local',
      );
      final remote = SyncRecord(
        id: '1',
        updatedAt: DateTime(2025, 1, 2),
        data: 'remote',
      );
      final result = ConflictResolver.resolve(local, remote);
      expect(result.data, 'remote');
    });

    test('equal timestamps: larger data wins', () {
      final ts = DateTime(2025);
      final local = SyncRecord(id: '1', updatedAt: ts, data: 'short');
      final remote = SyncRecord(id: '1', updatedAt: ts, data: 'much longer data');
      final result = ConflictResolver.resolve(local, remote);
      expect(result.data, 'much longer data');
    });

    test('equal timestamps and data size: local wins', () {
      final ts = DateTime(2025);
      final local = SyncRecord(id: '1', updatedAt: ts, data: 'same');
      final remote = SyncRecord(id: '1', updatedAt: ts, data: 'same');
      final result = ConflictResolver.resolve(local, remote);
      expect(result.data, 'same');
    });

    test('resolveBatch merges correctly', () {
      final local = {
        'a': SyncRecord(id: 'a', updatedAt: DateTime(2025, 1, 2), data: 'local_a'),
        'b': SyncRecord(id: 'b', updatedAt: DateTime(2025), data: 'local_b'),
      };
      final remote = {
        'a': SyncRecord(id: 'a', updatedAt: DateTime(2025), data: 'remote_a'),
        'b': SyncRecord(id: 'b', updatedAt: DateTime(2025, 1, 2), data: 'remote_b'),
        'c': SyncRecord(id: 'c', updatedAt: DateTime(2025), data: 'remote_c'),
      };
      final result = ConflictResolver.resolveBatch(local: local, remote: remote);
      expect(result.length, 3);
      expect(result['a']!.data, 'local_a');
      expect(result['b']!.data, 'remote_b');
      expect(result['c']!.data, 'remote_c');
    });
  });
}

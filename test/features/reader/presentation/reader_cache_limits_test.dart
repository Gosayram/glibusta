import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  group('base64Cache LRU eviction', () {
    setUp(() {
      clearBase64Cache();
    });

    Uint8List makeBytes(int n) => Uint8List.fromList([n]);

    test('stores and retrieves entries', () {
      final data = base64Encode(makeBytes(1));
      final result = cachedBase64Decode(data);
      expect(result, makeBytes(1));
      expect(base64CacheSize, 1);
    });

    test('evicts oldest entry when exceeding max size', () {
      for (var i = 0; i < 21; i++) {
        cachedBase64Decode(base64Encode(makeBytes(i)));
      }
      expect(base64CacheSize, 20);
    });

    test('returns correct values after eviction', () {
      final keys = <String>[];
      for (var i = 0; i < 21; i++) {
        final key = base64Encode(makeBytes(i));
        keys.add(key);
        cachedBase64Decode(key);
      }
      expect(cachedBase64Decode(keys.last), makeBytes(20));
      expect(base64CacheSize, 20);
    });

    test('accessing an entry promotes it (LRU)', () {
      final firstKey = base64Encode(makeBytes(0));
      cachedBase64Decode(firstKey);
      for (var i = 1; i <= 20; i++) {
        cachedBase64Decode(base64Encode(makeBytes(i)));
      }
      expect(base64CacheSize, 20);
      final result = cachedBase64Decode(firstKey);
      expect(result, makeBytes(0));
      expect(base64CacheSize, 20);
    });

    test('clear empties the cache', () {
      for (var i = 0; i < 10; i++) {
        cachedBase64Decode(base64Encode(makeBytes(i)));
      }
      expect(base64CacheSize, 10);
      clearBase64Cache();
      expect(base64CacheSize, 0);
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/storage/storage_bridge_impl.dart';

void main() {
  const channel = MethodChannel('com.gosayram.glibusta/storage_bridge');

  test('countBooks requests only the count for a selected SAF URI', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        expect(call.method, 'countBooks');
        expect(call.arguments, {'uri': 'content://tree/library'});
        return 42;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final count = await StorageBridgeImpl().countBooks('content://tree/library');

    expect(count, 42);
  });

  test('countBooks surfaces native failures to the folder settings flow', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'SCAN_ERROR'),
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await expectLater(
      StorageBridgeImpl().countBooks('content://tree/library'),
      throwsA(isA<PlatformException>()),
    );
  });
}

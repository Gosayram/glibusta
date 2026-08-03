import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider_2');
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('reader_img_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (call) async {
        if (call.method == 'getTemporaryDirectory' ||
            call.method == 'getApplicationDocumentsDirectory') {
          return tmpDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      null,
    );
    if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
  });

  testWidgets('image long-press shows share, save, and copy URL options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPress: () => showImageActions(context, 'http://example.com/img.png', 'Тест'),
              child: const Text('test'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('test'));
    await tester.pumpAndSettle();

    // Trigger long press via gesture
    await tester.longPress(find.text('test'));
    await tester.pumpAndSettle();

    expect(find.text('Поделиться изображением'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Копировать URL'), findsOneWidget);
  });

  testWidgets('copy URL puts image URL in clipboard', (tester) async {
    String? capturedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          capturedText = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': capturedText};
        }
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPress: () => showImageActions(
                context,
                'http://example.com/img.png',
                'Тестовое изображение',
              ),
              child: const Text('test'),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('test'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Копировать URL'));
    await tester.pumpAndSettle();

    expect(capturedText, 'http://example.com/img.png');
    expect(find.text('URL скопирован'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('save to device triggers save flow for data URI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPress: () => showImageActions(
                context,
                'data:image/png;base64,aGVsbG8=',
                'Тест',
              ),
              child: const Text('test'),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('test'));
    await tester.pumpAndSettle();

    // Tap save — dismisses the bottom sheet. The async file I/O path
    // exercises base64Decode + getApplicationDocumentsDirectory + writeAsBytes.
    // We verify the bottom sheet is dismissed (action was triggered).
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    // Bottom sheet should be dismissed after tap
    expect(find.text('Сохранить'), findsNothing);
  });

  testWidgets('save to device shows error for unsupported HTTP URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPress: () => showImageActions(
                context,
                'http://example.com/img.png',
                'Тест',
              ),
              child: const Text('test'),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('test'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Сохранение доступно только для локальных изображений'), findsOneWidget);
  });
}

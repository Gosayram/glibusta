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
    tmpDir = await Directory.systemTemp.createTemp('gallery_test_');
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

  const pngDataUri =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  Future<void> pumpViewer(
    WidgetTester tester, {
    required String imageUrl,
    List<String> allImages = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => showFullscreenImage(context, imageUrl, allImages: allImages),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The thumbnail strip is the only horizontal ListView in the viewer.
  Finder horizontalListViews() => find.byWidgetPredicate(
    (w) => w is ListView && w.scrollDirection == Axis.horizontal,
  );

  testWidgets('thumbnail strip is hidden for single image', (tester) async {
    await pumpViewer(tester, imageUrl: pngDataUri, allImages: [pngDataUri]);

    expect(horizontalListViews(), findsNothing);
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('thumbnail strip shows for multiple images', (tester) async {
    await pumpViewer(
      tester,
      imageUrl: pngDataUri,
      allImages: [pngDataUri, pngDataUri, pngDataUri],
    );

    expect(horizontalListViews(), findsOneWidget);
    // Three thumbnails, each wrapped in a GestureDetector.
    expect(
      find.descendant(of: horizontalListViews(), matching: find.byType(GestureDetector)),
      findsNWidgets(3),
    );
  });

  testWidgets('tapping thumbnail navigates to that image', (tester) async {
    await pumpViewer(
      tester,
      imageUrl: pngDataUri,
      allImages: [pngDataUri, pngDataUri, pngDataUri],
    );

    expect(find.text('1 / 3'), findsOneWidget);

    final thumbs = find.descendant(
      of: horizontalListViews(),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(thumbs.at(2), warnIfMissed: false);
    // The viewer's outer GestureDetector has an onDoubleTap handler, which
    // holds the gesture arena for the ~300ms double-tap timeout. The thumbnail's
    // onTap only resolves once that window elapses, so pump past it.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('counter shows correct index', (tester) async {
    // Distinct plain-path identifiers so indexOf yields a non-zero index.
    // These resolve to nonexistent files and render the broken-image icon,
    // which is fine — only the counter text is asserted.
    await pumpViewer(
      tester,
      imageUrl: 'img2',
      allImages: ['img0', 'img1', 'img2'],
    );

    // initialIndex = indexOf('img2') = 2 → counter "3 / 3".
    expect(find.text('3 / 3'), findsOneWidget);
  });
}

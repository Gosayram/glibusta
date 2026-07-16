import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/platform/share_handler.dart';
import 'package:glibusta/features/library/data/book_import_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  testWidgets('clears a consumed cold-start share intent', (tester) async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(path: 'unsupported.bin', type: SharedMediaType.file),
      ],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
    final handler = ShareHandler();
    late BuildContext context;
    addTearDown(() {
      handler.dispose();
      ReceiveSharingIntent.setMockValues(
        initialMedia: const [],
        mediaStream: const Stream<List<SharedMediaFile>>.empty(),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox();
          },
        ),
      ),
    );
    handler.init(context, (path) async => ImportResult.failure('unexpected: $path'));
    await tester.pump();

    expect(await ReceiveSharingIntent.instance.getInitialMedia(), isEmpty);
  });
}

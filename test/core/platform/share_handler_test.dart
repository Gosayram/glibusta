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

  testWidgets('copies a content URI before importing a cold-start share', (tester) async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(
          path: 'content://downloads/document/42',
          type: SharedMediaType.url,
        ),
      ],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
    final cachedUris = <String>[];
    final importedPaths = <String>[];
    final handler = ShareHandler(
      cacheSharedUri: (uri) async {
        cachedUris.add(uri);
        return '/cache/shared.epub';
      },
    );
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
    handler.init(context, (path) async {
      importedPaths.add(path);
      return ImportResult.failure('test import result');
    });
    await tester.pump();
    await tester.pump();

    expect(cachedUris, ['content://downloads/document/42']);
    expect(importedPaths, ['/cache/shared.epub']);
  });

  testWidgets('handles a failed content URI cache without an uncaught error', (tester) async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(
          path: 'content://downloads/document/42',
          type: SharedMediaType.url,
        ),
      ],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
    var imported = false;
    final handler = ShareHandler(
      cacheSharedUri: (_) async => throw StateError('SAF permission was revoked'),
    );
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
    handler.init(context, (_) async {
      imported = true;
      return ImportResult.failure('unexpected');
    });
    await tester.pump();
    await tester.pump();

    expect(imported, isFalse);
    expect(tester.takeException(), isNull);
  });
}

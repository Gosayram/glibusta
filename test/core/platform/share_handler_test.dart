import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/platform/share_handler.dart';
import 'package:glibusta/core/services/background_task_provider.dart';
import 'package:glibusta/core/services/task_queue_service.dart';
import 'package:glibusta/features/library/data/book_import_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class FakeTaskQueueService extends Fake implements TaskQueueService {
  final importCalls = <String>[];

  @override
  Future<T> run<T>({
    required BackgroundTaskType type,
    required String message,
    required Future<T> Function() task,
    String Function(T result)? successMessage,
  }) async {
    final result = await task();
    return result;
  }
}

void main() {
  final fakeTaskQueue = FakeTaskQueueService();

  testWidgets('clears a consumed cold-start share intent', (tester) async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(path: 'unsupported.bin', type: SharedMediaType.file),
      ],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
    final handler = ShareHandler(taskQueue: fakeTaskQueue);
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
      taskQueue: fakeTaskQueue,
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
      taskQueue: fakeTaskQueue,
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

  testWidgets('reinitializing only imports live Open-with files once', (tester) async {
    final mediaController = StreamController<List<SharedMediaFile>>.broadcast(sync: true);
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: mediaController.stream,
    );
    final handler = ShareHandler(taskQueue: fakeTaskQueue);
    final firstImports = <String>[];
    final secondImports = <String>[];
    late BuildContext context;
    addTearDown(() async {
      handler.dispose();
      await mediaController.close();
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
      firstImports.add(path);
      return ImportResult.failure('unexpected');
    });
    handler.init(context, (path) async {
      secondImports.add(path);
      return ImportResult.failure('test import result');
    });

    mediaController.add([
      SharedMediaFile(path: '/cache/reopened.epub', type: SharedMediaType.file),
    ]);
    await tester.pump();

    expect(firstImports, isEmpty);
    expect(secondImports, ['/cache/reopened.epub']);
  });

  testWidgets('does not finish a stale Open-with import after reinitializing', (tester) async {
    final mediaController = StreamController<List<SharedMediaFile>>.broadcast(sync: true);
    final cacheStarted = Completer<void>();
    final cachedPath = Completer<String?>();
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: mediaController.stream,
    );
    final handler = ShareHandler(
      taskQueue: fakeTaskQueue,
      cacheSharedUri: (_) {
        cacheStarted.complete();
        return cachedPath.future;
      },
    );
    final firstImports = <String>[];
    final secondImports = <String>[];
    late BuildContext context;
    addTearDown(() async {
      handler.dispose();
      await mediaController.close();
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
      firstImports.add(path);
      return ImportResult.failure('unexpected');
    });

    mediaController.add([
      SharedMediaFile(path: 'content://downloads/document/42', type: SharedMediaType.url),
    ]);
    await cacheStarted.future;

    handler.init(context, (path) async {
      secondImports.add(path);
      return ImportResult.failure('unexpected');
    });
    cachedPath.complete('/cache/stale.epub');
    await tester.pump();
    await tester.pump();

    expect(firstImports, isEmpty);
    expect(secondImports, isEmpty);
  });
}

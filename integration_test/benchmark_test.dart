import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// Baseline macrobenchmark: startup time + 3s timeline trace.
///
/// Run on a connected Android device:
///   flutter test integration_test/benchmark_test.dart --profile
///
/// Output: build/benchmark/timeline.json (open in chrome://tracing)
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baseline startup profile', (tester) async {
    // ── Cold start ──────────────────────────────────────────────────────
    final stopwatch = Stopwatch()..start();

    await app.main();

    // Wait for app to settle (library screen renders, etc.)
    await tester.pumpAndSettle(const Duration(seconds: 15));
    final startupMs = stopwatch.elapsedMilliseconds;

    // ── Trace 3s of idle / interaction ──────────────────────────────────
    final timeline = await binding.traceTimeline(
      () async => Future<void>.delayed(const Duration(seconds: 3)),
    );

    // ── Save trace for chrome://tracing ─────────────────────────────────
    final outDir = Directory('build/benchmark');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final traceFile = File('${outDir.path}/timeline.json');
    await traceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(timeline.toJson()),
    );

    // ignore: avoid_print
    print('[BENCH] startup: ${startupMs}ms, trace: ${traceFile.path}');
  });
}

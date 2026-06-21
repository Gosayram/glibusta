import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetry/reader_telemetry.dart' as telemetry;

final bookStatsListProvider = FutureProvider.autoDispose<Map<String, telemetry.BookStats>>((
  ref,
) async {
  final telemetryRepo = ref.watch(telemetry.readerTelemetryProvider);
  return telemetryRepo.getAllStats();
});

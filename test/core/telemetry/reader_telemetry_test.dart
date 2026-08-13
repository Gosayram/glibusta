import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/telemetry/reader_telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('groups frequent errors by message rather than book id', () async {
    SharedPreferences.setMockInitialValues({
      'reader_errors': [
        'book-a|Network timeout|2026-01-01T00:00:00.000',
        'book-b|Network timeout|2026-01-02T00:00:00.000',
        'book-c|Unsupported format|2026-01-03T00:00:00.000',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final telemetry = ReaderTelemetry(prefs, AppLogger());

    final errors = await telemetry.getFrequentErrors();

    expect(errors.first, 'Network timeout');
  });
}

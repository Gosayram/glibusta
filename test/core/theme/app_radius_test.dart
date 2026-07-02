import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_radius.dart';

void main() {
  group('AppRadius', () {
    test('scale values', () {
      expect(AppRadius.xs, 4.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 24.0);
    });
  });
}

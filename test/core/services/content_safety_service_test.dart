import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/services/content_safety_service.dart';

void main() {
  group('ContentSafetyLevel', () {
    test('has correct display names', () {
      expect(ContentSafetyLevel.standard.displayName, 'Стандартный');
      expect(ContentSafetyLevel.moderate.displayName, 'Умеренный');
      expect(ContentSafetyLevel.strict.displayName, 'Строгий');
    });

    test('has correct descriptions', () {
      expect(ContentSafetyLevel.standard.description, 'Показывать весь контент');
      expect(ContentSafetyLevel.moderate.description, 'Скрывать откровенный контент');
      expect(ContentSafetyLevel.strict.description, 'Показывать только безопасный контент');
    });

    test('index values are sequential', () {
      expect(ContentSafetyLevel.standard.index, 0);
      expect(ContentSafetyLevel.moderate.index, 1);
      expect(ContentSafetyLevel.strict.index, 2);
    });
  });
}

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

  group('ContentSafetyService.shouldFilter', () {
    test('standard never filters', () {
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.standard, ['adult', '18+']),
          isFalse);
    });

    test('moderate filters explicit tags', () {
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.moderate, ['adult']),
          isTrue);
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.moderate, ['erotic']),
          isTrue);
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.moderate, ['nsfw']),
          isTrue);
    });

    test('moderate does not filter safe tags', () {
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.moderate, ['fiction', 'sci-fi']),
          isFalse);
    });

    test('strict filters explicit + unsafe tags', () {
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.strict, ['violence']),
          isTrue);
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.strict, ['gore']),
          isTrue);
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.strict, ['horror']),
          isTrue);
    });

    test('filter is case-insensitive', () {
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.moderate, ['ADULT']),
          isTrue);
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.strict, ['Horror']),
          isTrue);
    });

    test('empty tags never filter', () {
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.moderate, []),
          isFalse);
      expect(ContentSafetyService.shouldFilter(
          ContentSafetyLevel.strict, []),
          isFalse);
    });
  });

  group('ContentSafetyService.shouldFilterTitle', () {
    test('standard never filters', () {
      expect(ContentSafetyService.shouldFilterTitle(
          ContentSafetyLevel.standard, 'Adult Book 18+'),
          isFalse);
    });

    test('moderate filters explicit words', () {
      expect(ContentSafetyService.shouldFilterTitle(
          ContentSafetyLevel.moderate, 'Erotic Novel'),
          isTrue);
    });

    test('strict filters unsafe words', () {
      expect(ContentSafetyService.shouldFilterTitle(
          ContentSafetyLevel.strict, 'Horror Story'),
          isTrue);
    });

    test('safe title not filtered', () {
      expect(ContentSafetyService.shouldFilterTitle(
          ContentSafetyLevel.strict, 'Война и мир'),
          isFalse);
    });
  });
}

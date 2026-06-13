import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/config/feature_flags.dart';

void main() {
  group('FeatureFlag', () {
    test('has correct fields', () {
      const flag = FeatureFlag(
        key: 'test_flag',
        name: 'Test Flag',
        description: 'A test flag',
        defaultValue: true,
        isExperimental: true,
      );
      expect(flag.key, 'test_flag');
      expect(flag.name, 'Test Flag');
      expect(flag.defaultValue, isTrue);
      expect(flag.isExperimental, isTrue);
    });
  });

  group('FeatureFlagDefs', () {
    test('all returns list of flags', () {
      expect(FeatureFlagDefs.all.length, greaterThan(0));
    });

    test('newReaderEngine is experimental', () {
      expect(FeatureFlagDefs.newReaderEngine.isExperimental, isTrue);
    });

    test('newCardDesign is not experimental', () {
      expect(FeatureFlagDefs.newCardDesign.isExperimental, isFalse);
    });

    test('experimentalPdf is experimental', () {
      expect(FeatureFlagDefs.experimentalPdf.isExperimental, isTrue);
    });

    test('flags have unique keys', () {
      final keys = FeatureFlagDefs.all.map((f) => f.key).toSet();
      expect(keys.length, FeatureFlagDefs.all.length);
    });

    test('all flags have non-empty name and description', () {
      for (final flag in FeatureFlagDefs.all) {
        expect(flag.name.isNotEmpty, isTrue);
        expect(flag.description.isNotEmpty, isTrue);
      }
    });
  });
}

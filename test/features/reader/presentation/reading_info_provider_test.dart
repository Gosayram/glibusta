import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_model.dart';
import 'package:glibusta/features/reader/presentation/reading_info_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a local update wins over an in-flight saved settings load', () async {
    SharedPreferences.setMockInitialValues({
      'reading_info_config': jsonEncode(
        const ReadingInfoModel(fontSize: 18).toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(readingInfoProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(container.read(readingInfoProvider).fontSize, 12);
    final notifier = container.read(readingInfoProvider.notifier);
    notifier.updateFontSize(22);

    await Future<void>.delayed(Duration.zero);

    expect(container.read(readingInfoProvider).fontSize, 22);
  });

  test('a reset wins over an in-flight saved settings load', () async {
    SharedPreferences.setMockInitialValues({
      'reading_info_config': jsonEncode(
        const ReadingInfoModel(margin: 20).toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(readingInfoProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(container.read(readingInfoProvider).margin, 8);
    container.read(readingInfoProvider.notifier).reset();

    await Future<void>.delayed(Duration.zero);

    expect(container.read(readingInfoProvider).margin, 8);
  });
}

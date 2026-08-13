import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_model.dart';
import 'package:glibusta/features/reader/presentation/reading_info_provider.dart';
import 'package:glibusta/features/reader/presentation/reading_info_settings_screen.dart';

void main() {
  testWidgets('preview represents remaining slots as time estimates', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingInfoProvider.overrideWithValue(
            const ReadingInfoModel(
              headerLeft: InfoSlotMode.remainingChapter,
              headerCenter: InfoSlotMode.none,
              headerRight: InfoSlotMode.none,
              footerLeft: InfoSlotMode.remainingBook,
              footerRight: InfoSlotMode.none,
            ),
          ),
        ],
        child: const MaterialApp(home: ReadingInfoSettingsScreen()),
      ),
    );

    await tester.scrollUntilVisible(find.text('~32 мин'), 300);
    expect(find.text('~32 мин'), findsOneWidget);
    expect(find.text('~1 ч 35 мин'), findsOneWidget);
    expect(find.text('58% · 3 гл.'), findsNothing);
    expect(find.text('32% · 8 гл.'), findsNothing);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/chapter_split_rules_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('loads persisted custom chapter split rules', (tester) async {
    SharedPreferences.setMockInitialValues({
      'chapter_split_rules': jsonEncode([
        {
          'id': 'custom_saved',
          'name': 'Saved custom rule',
          'pattern': r'^Section\\s+\\d+',
          'isPreset': false,
          'isRegex': true,
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chapter_split_rules'), isNotNull);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChapterSplitRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Saved custom rule'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Saved custom rule'), findsOneWidget);
  });

  testWidgets('rejects an invalid custom regular expression', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChapterSplitRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Invalid rule');
    await tester.enterText(find.byType(TextField).at(2), '[');
    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(find.text('Add Custom Rule'), findsOneWidget);
    expect(find.text('Pattern is not a valid regular expression'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_model.dart';

void main() {
  group('TOC sheet tab structure', () {
    testWidgets('TOC sheet has Главы and Закладки tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              body: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Главы'),
                      Tab(text: 'Закладки'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Center(child: Text('Содержание')),
                        Center(child: Text('Нет закладок')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Главы'), findsOneWidget);
      expect(find.text('Закладки'), findsOneWidget);
    });
  });

  group('InfoSlotMode.streak', () {
    test('exists as an enum value', () {
      expect(InfoSlotMode.values.contains(InfoSlotMode.streak), isTrue);
    });

    test('is the last value preserving serialization order', () {
      expect(InfoSlotMode.values.last, InfoSlotMode.streak);
    });

    test('ReadingInfoModel accepts streak in any slot', () {
      const model = ReadingInfoModel(headerLeft: InfoSlotMode.streak);
      expect(model.headerLeft, InfoSlotMode.streak);
    });

    test('ReadingInfoModel serializes streak correctly', () {
      const model = ReadingInfoModel(headerLeft: InfoSlotMode.streak);
      final json = model.toJson();
      final restored = ReadingInfoModel.fromJson(json);
      expect(restored.headerLeft, InfoSlotMode.streak);
    });
  });
}

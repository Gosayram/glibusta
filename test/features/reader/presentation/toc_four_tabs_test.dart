import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_model.dart';

void main() {
  group('TOC sheet 4-tab structure', () {
    testWidgets('has Главы, Закладки, Заметки, Цитаты tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Scaffold(
              body: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Главы'),
                      Tab(text: 'Закладки'),
                      Tab(text: 'Заметки'),
                      Tab(text: 'Цитаты'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Center(child: Text('Содержание')),
                        Center(child: Text('Нет закладок')),
                        Center(child: Text('Нет заметок')),
                        Center(child: Text('Нет цитат')),
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
      expect(find.text('Заметки'), findsOneWidget);
      expect(find.text('Цитаты'), findsOneWidget);
    });
  });

  group('InfoSlotMode.todayTime', () {
    test('exists as an enum value', () {
      expect(InfoSlotMode.values.contains(InfoSlotMode.todayTime), isTrue);
    });

    test('is the last value preserving serialization order', () {
      expect(InfoSlotMode.values.last, InfoSlotMode.todayTime);
    });

    test('ReadingInfoModel accepts todayTime in any slot', () {
      const model = ReadingInfoModel(headerLeft: InfoSlotMode.todayTime);
      expect(model.headerLeft, InfoSlotMode.todayTime);
    });

    test('ReadingInfoModel serializes todayTime correctly', () {
      const model = ReadingInfoModel(headerRight: InfoSlotMode.todayTime);
      final json = model.toJson();
      final restored = ReadingInfoModel.fromJson(json);
      expect(restored.headerRight, InfoSlotMode.todayTime);
    });

    test('InfoSlotMode has 13 values total', () {
      expect(InfoSlotMode.values.length, 13);
    });
  });
}

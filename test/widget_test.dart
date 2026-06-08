import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/app/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GlibustaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Glibusta'), findsOneWidget);
    expect(find.text('Найти книгу'), findsOneWidget);
  });

  testWidgets('App has navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GlibustaApp()));
    await tester.pumpAndSettle();

    // Should have navigation destinations
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Поиск'), findsOneWidget);
    expect(find.text('Библиотека'), findsOneWidget);
    expect(find.text('Загрузки'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });
}

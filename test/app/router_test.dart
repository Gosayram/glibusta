import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/app/router.dart';

void main() {
  testWidgets('unknown route renders an error without redirecting', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    addTearDown(router.dispose);

    router.go('/definitely-missing');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Страница не найдена или произошла ошибка навигации'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/definitely-missing');
  });
}

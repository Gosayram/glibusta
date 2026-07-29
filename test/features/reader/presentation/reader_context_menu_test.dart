import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_context_menu.dart';

void main() {
  testWidgets('exposes selection actions as individual accessible buttons', (tester) async {
    final semantics = tester.ensureSemantics();
    ContextMenuAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderContextMenu(
            selectedText: 'Выделенный фрагмент',
            onAction: (action) => selectedAction = action,
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Действия с выделенным текстом')),
      matchesSemantics(
        label: 'Действия с выделенным текстом',
        namesRoute: true,
        scopesRoute: true,
      ),
    );
    final copy = find.bySemanticsLabel('Копировать');
    expect(copy, findsOneWidget);
    expect(
      tester.getSemantics(copy),
      matchesSemantics(
        label: 'Копировать',
        isButton: true,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Копировать'));
    expect(selectedAction, ContextMenuAction.copy);

    semantics.dispose();
  });
}

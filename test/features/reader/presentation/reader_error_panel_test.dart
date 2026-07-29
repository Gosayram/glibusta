import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';
import 'package:glibusta/features/reader/presentation/reader_error_panel.dart';

void main() {
  testWidgets('announces a reader error once as a live region', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderErrorSummary(
            kind: ReaderErrorKind.unsupportedFormat,
            message: 'Этот файл нельзя открыть.',
          ),
        ),
      ),
    );

    final summary = find.bySemanticsLabel(
      'Формат не поддерживается. Этот файл нельзя открыть.',
    );
    expect(summary, findsOneWidget);
    expect(
      tester.getSemantics(summary),
      matchesSemantics(
        label: 'Формат не поддерживается. Этот файл нельзя открыть.',
        isLiveRegion: true,
      ),
    );
    expect(find.bySemanticsLabel('Формат не поддерживается'), findsNothing);
    expect(find.bySemanticsLabel('Этот файл нельзя открыть.'), findsNothing);

    semantics.dispose();
  });
}

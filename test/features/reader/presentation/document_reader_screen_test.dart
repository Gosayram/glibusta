import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/djvu_reader_screen.dart';
import 'package:glibusta/features/reader/presentation/pdf_reader_screen.dart';

void main() {
  String missingDocumentPath(String extension) =>
      '${Directory.systemTemp.path}/glibusta-missing-${DateTime.now().microsecondsSinceEpoch}.$extension';

  testWidgets('PDF reader reports a missing document instead of creating a viewer', (tester) async {
    final path = missingDocumentPath('pdf');

    await tester.pumpWidget(MaterialApp(home: PdfReaderScreen(filePath: path)));

    expect(find.text('Файл не найден: $path'), findsOneWidget);
  });

  testWidgets('DjVu reader reports a missing document instead of calling Rust', (tester) async {
    final path = missingDocumentPath('djvu');

    await tester.pumpWidget(MaterialApp(home: DjvuReaderScreen(filePath: path)));
    await tester.pump();

    expect(find.text('Файл не найден'), findsOneWidget);
  });
}

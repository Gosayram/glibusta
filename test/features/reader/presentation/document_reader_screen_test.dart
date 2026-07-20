import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/djvu_reader_screen.dart';
import 'package:glibusta/features/reader/presentation/pdf_reader_screen.dart';
import 'package:pdfrx/pdfrx.dart';

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

  group('PDF link safety', () {
    test('allows only an in-document destination within the page range', () {
      const destination = PdfDest(2, PdfDestCommand.fit, null);
      const link = PdfLink([], dest: destination);

      expect(isSafePdfLink(link, 2), isTrue);
      expect(isSafePdfLink(link, 1), isFalse);
    });

    test('rejects malformed and external URI links', () {
      const invalidDestination = PdfDest(0, PdfDestCommand.fit, null);
      const invalidLink = PdfLink([], dest: invalidDestination);
      final externalLink = PdfLink([], url: Uri.parse('https://attacker.invalid/callback'));

      expect(isSafePdfLink(invalidLink, 10), isFalse);
      expect(isSafePdfLink(externalLink, 10), isFalse);
    });
  });

  group('PDF text availability', () {
    test('reports an image-only or whitespace-only document as not searchable', () {
      expect(
        PdfTextAvailability.fromPageTexts(['', '  \n\t']),
        PdfTextAvailability.unavailable,
      );
    });

    test('keeps search available when any page has extracted text', () {
      expect(
        PdfTextAvailability.fromPageTexts(['', 'Глава 1']),
        PdfTextAvailability.available,
      );
    });
  });
}

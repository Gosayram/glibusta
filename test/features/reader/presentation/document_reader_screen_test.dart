import 'dart:io';
import 'dart:typed_data';

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

  testWidgets('image-only PDF keeps rendering but disables text search', (tester) async {
    final file = File(
      '${Directory.systemTemp.path}/glibusta-image-only-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(_imageOnlyPdfBytes());
    addTearDown(file.delete);

    final semanticsHandle = tester.ensureSemantics();
    addTearDown(semanticsHandle.dispose);

    await tester.pumpWidget(MaterialApp(home: PdfReaderScreen(filePath: file.path)));
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.text('В PDF не найден извлекаемый текст. Поиск и копирование недоступны.'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(find.byIcon(Icons.search)).onPressed, isNull);
    expect(
      find.bySemanticsLabel('В PDF не найден извлекаемый текст. Поиск и копирование недоступны.'),
      findsOneWidget,
    );
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

Uint8List _imageOnlyPdfBytes() {
  final objects = <List<int>>[
    '%PDF-1.4\n'.codeUnits,
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'.codeUnits,
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'.codeUnits,
    '''
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100]
   /Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >>
endobj
'''
        .codeUnits,
    '4 0 obj\n<< /Length 31 >>\nstream\nq 100 0 0 100 0 0 cm /Im0 Do Q\nendstream\nendobj\n'
        .codeUnits,
    <int>[
      ...'5 0 obj\n<< /Type /XObject /Subtype /Image /Width 1 /Height 1 '
              '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 3 >>\nstream\n'
          .codeUnits,
      255,
      255,
      255,
      ...'\nendstream\nendobj\n'.codeUnits,
    ],
  ];
  final offsets = <int>[];
  var length = objects.first.length;
  for (final object in objects.skip(1)) {
    offsets.add(length);
    length += object.length;
  }
  final xrefOffset = length;
  final xref = StringBuffer('xref\n0 6\n0000000000 65535 f \n');
  for (final offset in offsets) {
    xref.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
  }
  xref.write('trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');

  return Uint8List.fromList([...objects.expand((object) => object), ...xref.toString().codeUnits]);
}

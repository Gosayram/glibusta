import 'dart:async';
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

  testWidgets('image-only PDF state keeps the viewer rendering and disables text search', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/glibusta-image-only-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes([0]);
    addTearDown(file.delete);

    final semanticsHandle = tester.ensureSemantics();
    addTearDown(semanticsHandle.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PdfReaderScreen(
          filePath: file.path,
          testViewer: const SizedBox(key: Key('fake-pdf-viewer')),
          testTextAvailabilityLoader: () async => PdfTextAvailability.unavailable,
        ),
      ),
    );
    await tester.pump();

    // The production PDFium integration remains device-tested. This widget
    // test verifies the reader state without loading a native FFI backend.
    expect(find.byKey(const Key('fake-pdf-viewer')), findsOneWidget);
    expect(
      find.text('В PDF не найден извлекаемый текст. Поиск и копирование недоступны.'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(find.byIcon(Icons.search)).onPressed, isNull);
    expect(isPdfTextSelectionEnabled(PdfTextAvailability.unavailable), isFalse);
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

  testWidgets('DjVu reader ignores a stale page-render failure after a newer page wins', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/glibusta-djvu-${DateTime.now().microsecondsSinceEpoch}.djvu',
    );
    await file.writeAsBytes([0]);
    addTearDown(file.delete);

    final secondPage = Completer<Uint8List>();
    final returnToFirstPage = Completer<Uint8List>();
    var firstPageLoads = 0;

    Future<Uint8List> loadThumbnail({
      required String path,
      required int pageIndex,
      required int maxWidth,
    }) {
      expect(path, file.path);
      expect(maxWidth, 1080);
      if (pageIndex == 1) return secondPage.future;
      firstPageLoads++;
      return firstPageLoads == 1
          ? Future<Uint8List>.value(_transparentPng)
          : returnToFirstPage.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: DjvuReaderScreen(
          filePath: file.path,
          pageCountLoader: (_) async => 2,
          thumbnailLoader: loadThumbnail,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    returnToFirstPage.complete(_transparentPng);
    await tester.pump();
    secondPage.completeError(StateError('stale page failed'));
    await tester.pump();

    expect(find.text('stale page failed'), findsNothing);
    expect(find.text('1 / 2'), findsWidgets);
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

    test('keeps selection disabled only when text extraction is unavailable', () {
      expect(isPdfTextSelectionEnabled(null), isTrue);
      expect(isPdfTextSelectionEnabled(PdfTextAvailability.available), isTrue);
      expect(isPdfTextSelectionEnabled(PdfTextAvailability.unavailable), isFalse);
    });

    test('samples at most the first ten pages before declaring a PDF image-only', () async {
      final loadedPages = <int>[];
      final availability = await detectPdfTextAvailability(
        List.generate(
          12,
          (index) => () async {
            loadedPages.add(index + 1);
            return index == 10 ? 'Text beyond the opening sample' : ' \n\t ';
          },
        ),
      );

      expect(availability, PdfTextAvailability.unavailable);
      expect(loadedPages, List.generate(pdfTextAvailabilitySamplePageLimit, (index) => index + 1));
    });

    test('stops the bounded sample as soon as it finds extracted text', () async {
      final loadedPages = <int>[];
      final availability = await detectPdfTextAvailability([
        () async {
          loadedPages.add(1);
          return '  ';
        },
        () async {
          loadedPages.add(2);
          return 'Глава 1';
        },
        () async {
          loadedPages.add(3);
          return 'must not be loaded';
        },
      ]);

      expect(availability, PdfTextAvailability.available);
      expect(loadedPages, [1, 2]);
    });
  });
}

final Uint8List _transparentPng = Uint8List.fromList(<int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  255,
  255,
  255,
  127,
  0,
  9,
  251,
  3,
  253,
  42,
  134,
  225,
  56,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

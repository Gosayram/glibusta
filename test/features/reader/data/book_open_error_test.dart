import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/errors/failures.dart';
import 'package:glibusta/features/reader/data/book_open_service.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';
import 'package:glibusta/features/reader/presentation/reader_error_panel.dart';

void main() {
  group('BookOpenError enum', () {
    test('corruptFile has user-facing Russian message', () {
      expect(BookOpenError.corruptFile.userMessage, contains('повреждён'));
    });

    test('missingContent has user-facing Russian message', () {
      expect(BookOpenError.missingContent.userMessage, contains('Содержимое'));
    });

    test('emptyBook has user-facing Russian message', () {
      expect(BookOpenError.emptyBook.userMessage, contains('текста'));
    });

    test('unsupportedFormat has user-facing Russian message', () {
      expect(BookOpenError.unsupportedFormat.userMessage, contains('Формат'));
    });
  });

  group('ReaderErrorKind new values', () {
    test('corruptFile has Russian title', () {
      expect(ReaderErrorKind.corruptFile.defaultTitle, 'Файл повреждён');
    });

    test('missingContent has Russian title', () {
      expect(ReaderErrorKind.missingContent.defaultTitle, 'Отсутствует содержимое');
    });

    test('emptyBook has Russian title', () {
      expect(ReaderErrorKind.emptyBook.defaultTitle, 'Пустая книга');
    });

    test('corruptFile uses broken image icon', () {
      expect(ReaderErrorKind.corruptFile.icon, Icons.broken_image_outlined);
    });

    test('missingContent uses article icon', () {
      expect(ReaderErrorKind.missingContent.icon, Icons.article_outlined);
    });

    test('emptyBook uses menu book icon', () {
      expect(ReaderErrorKind.emptyBook.icon, Icons.menu_book_outlined);
    });
  });

  group('CorruptFileFailure classification', () {
    test('CorruptFileFailure maps to corruptFile', () {
      const error = CorruptFileFailure('Invalid ZIP header');
      final kind = _classifyForTest(error);
      expect(kind, ReaderErrorKind.corruptFile);
    });

    test('ArchiveException is caught and classified as corruptFile upstream', () {
      final error = ArchiveException('Invalid ZIP header');
      expect(error.toString(), contains('ZIP'));
    });

    test('StateError with EPUB file not found indicates corruption', () {
      final error = StateError('EPUB file not found: mimetype');
      expect(error.toString(), contains('EPUB file not found'));
    });
  });

  group('MissingContentFailure classification', () {
    test('MissingContentFailure maps to missingContent', () {
      const error = MissingContentFailure('OPF not found');
      final kind = _classifyForTest(error);
      expect(kind, ReaderErrorKind.missingContent);
    });

    test('OPF not found error message is descriptive', () {
      final error = StateError('Invalid EPUB: OPF path not found');
      expect(error.toString(), contains('OPF'));
    });
  });

  group('User-friendly error messages', () {
    test('CorruptFileFailure returns corruptFile message', () {
      const failure = CorruptFileFailure('bad zip');
      final message = _friendlyMessageForTest(failure);
      expect(message, contains('повреждён'));
      expect(message, isNot(contains('CorruptFileFailure')));
    });

    test('MissingContentFailure returns missingContent message', () {
      const failure = MissingContentFailure('no opf');
      final message = _friendlyMessageForTest(failure);
      expect(message, contains('Содержимое'));
      expect(message, isNot(contains('MissingContentFailure')));
    });

    test('other errors fall back to toString', () {
      final error = Exception('some unexpected error');
      final message = _friendlyMessageForTest(error);
      expect(message, contains('some unexpected error'));
    });
  });

  group('ReaderErrorPanel with new error kinds', () {
    testWidgets('shows corruptFile title and retry button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderErrorSummary(
              kind: ReaderErrorKind.corruptFile,
              message: BookOpenError.corruptFile.userMessage,
            ),
          ),
        ),
      );

      expect(find.text('Файл повреждён'), findsOneWidget);
      expect(find.text(BookOpenError.corruptFile.userMessage), findsOneWidget);
    });

    testWidgets('shows missingContent title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderErrorSummary(
              kind: ReaderErrorKind.missingContent,
              message: BookOpenError.missingContent.userMessage,
            ),
          ),
        ),
      );

      expect(find.text('Отсутствует содержимое'), findsOneWidget);
    });

    testWidgets('shows emptyBook title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderErrorSummary(
              kind: ReaderErrorKind.emptyBook,
              message: BookOpenError.emptyBook.userMessage,
            ),
          ),
        ),
      );

      expect(find.text('Пустая книга'), findsOneWidget);
    });

    testWidgets('corruptFile summary is a live region for accessibility', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderErrorSummary(
              kind: ReaderErrorKind.corruptFile,
              message: BookOpenError.corruptFile.userMessage,
            ),
          ),
        ),
      );

      final summary = find.bySemanticsLabel(
        'Файл повреждён. ${BookOpenError.corruptFile.userMessage}',
      );
      expect(summary, findsOneWidget);
      expect(
        tester.getSemantics(summary),
        matchesSemantics(
          label: 'Файл повреждён. ${BookOpenError.corruptFile.userMessage}',
          isLiveRegion: true,
        ),
      );

      semantics.dispose();
    });
  });
}

ReaderErrorKind _classifyForTest(Object error) => switch (error) {
  BookMissingFailure() => ReaderErrorKind.bookMissing,
  UnsupportedFormatFailure() => ReaderErrorKind.unsupportedFormat,
  ParserTimeoutFailure() => ReaderErrorKind.parserTimeout,
  CacheCorruptedFailure() => ReaderErrorKind.cacheCorrupted,
  InvalidEncodingFailure() => ReaderErrorKind.invalidEncoding,
  CorruptFileFailure() => ReaderErrorKind.corruptFile,
  MissingContentFailure() => ReaderErrorKind.missingContent,
  _ => ReaderErrorKind.unknown,
};

String _friendlyMessageForTest(Object error) => switch (error) {
  CorruptFileFailure() => BookOpenError.corruptFile.userMessage,
  MissingContentFailure() => BookOpenError.missingContent.userMessage,
  _ => error.toString(),
};

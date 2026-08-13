import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const bookMimeTypes = <String>[
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-word.document.macroenabled.12',
    'application/vnd.comicbook+zip',
    'application/vnd.comicbook-rar',
  ];

  test('Android share and view filters advertise supported document and comic formats', () async {
    final manifest = await File(manifestPath).readAsString();

    for (final mimeType in bookMimeTypes) {
      expect(
        RegExp('android:mimeType="${RegExp.escape(mimeType)}"').allMatches(manifest),
        hasLength(3),
        reason: '$mimeType must be accepted by SEND, SEND_MULTIPLE, and VIEW intents',
      );
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/dictionary_lookup_preview.dart';

void main() {
  group('DictionaryLookupPreview', () {
    test('normalizes whitespace without changing a short visible query', () {
      expect(DictionaryLookupPreview.text('  слово\n\tкниги  '), 'слово книги');
      expect(DictionaryLookupPreview.isTruncated('слово книги'), isFalse);
    });

    test('truncates by Unicode runes and tells the reader the full query is sent', () {
      final query = '${'я'.padRight(DictionaryLookupPreview.maxPreviewRunes, 'я')}🙂хвост';

      final message = DictionaryLookupPreview.confirmationMessage(
        host: 'dictionary.example',
        query: query,
      );

      expect(DictionaryLookupPreview.text(query), endsWith('…'));
      expect(DictionaryLookupPreview.isTruncated(query), isTrue);
      expect(message, contains('dictionary.example'));
      expect(
        message,
        contains('Показано начало; источнику будет передан весь выбранный фрагмент.'),
      );
    });
  });
}

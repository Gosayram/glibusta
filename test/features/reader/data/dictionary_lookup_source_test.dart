import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/dictionary_lookup_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('accepts an HTTPS template and encodes only the lookup substitutions', () {
    const source = DictionaryLookupSource(
      template: 'https://dictionary.example/lookup/{word}?lang={lang}',
      language: 'ru',
    );

    expect(source.validationError(), isNull);
    expect(
      source.resolve('слово & значение').toString(),
      'https://dictionary.example/lookup/%D1%81%D0%BB%D0%BE%D0%B2%D0%BE%20%26%20%D0%B7%D0%BD%D0%B0%D1%87%D0%B5%D0%BD%D0%B8%D0%B5?lang=ru',
    );
  });

  test('allows cleartext only for explicit local development sources', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]']) {
      final source = DictionaryLookupSource(
        template: 'http://$host:8080/lookup/{word}',
        language: 'en',
      );
      expect(source.validationError(), isNull, reason: host);
    }

    const remote = DictionaryLookupSource(
      template: 'http://dictionary.example/lookup/{word}',
      language: 'en',
    );
    expect(remote.validationError(), 'Разрешены только HTTPS или локальный HTTP-адрес');
  });

  test('rejects unsafe, incomplete, or unsupported source settings', () {
    const cases = [
      DictionaryLookupSource(
        template: 'https://dictionary.example/lookup',
        language: 'en',
      ),
      DictionaryLookupSource(
        template: 'https://user:password@dictionary.example/{word}',
        language: 'en',
      ),
      DictionaryLookupSource(
        template: 'https://dictionary.example/{word}?api_key=secret',
        language: 'en',
      ),
      DictionaryLookupSource(
        template: 'https://dictionary.example/{word}',
        language: 'xx',
      ),
      DictionaryLookupSource(
        template: 'https://dictionary.example/{word}/{unknown}',
        language: 'en',
      ),
    ];

    for (final source in cases) {
      expect(source.validationError(), isNotNull);
    }
  });

  test('persists only a valid custom source and ignores invalid stored data', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = DictionaryLookupSourceStore(preferences);
    const source = DictionaryLookupSource(
      template: 'https://dictionary.example/{lang}/{word}',
      language: 'uk',
    );

    await store.save(source);
    expect(
      store.load()?.resolve('книга').toString(),
      'https://dictionary.example/uk/%D0%BA%D0%BD%D0%B8%D0%B3%D0%B0',
    );

    await preferences.setString(
      'reader_dictionary_lookup_source',
      '{"template":"http://dictionary.example/{word}","language":"en"}',
    );
    expect(store.load(), isNull);

    await store.clear();
    expect(store.load(), isNull);
  });
}

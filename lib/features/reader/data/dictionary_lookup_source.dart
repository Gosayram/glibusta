import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A user-configured dictionary endpoint for explicit reader lookups.
///
/// The endpoint is deliberately a URL template rather than an HTTP client
/// configuration: no credentials, headers, or background requests are stored
/// by the reader. A lookup can therefore only leave the device after its own
/// confirmation dialog.
class DictionaryLookupSource {
  const DictionaryLookupSource({
    required this.template,
    required this.language,
  });

  static const supportedLanguages = <String>{
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'ru',
    'uk',
  };

  static const _wordMarker = 'glibusta-dictionary-word';
  static const _languageMarker = 'glibusta-dictionary-language';
  static final _sensitiveQueryParameter = RegExp(
    r'^(?:access_?)?token$|^(?:api_?)?key$|^auth(?:orization)?$|^password$|^secret$',
    caseSensitive: false,
  );

  final String template;
  final String language;

  /// Returns a user-facing validation message, or `null` for a safe source.
  String? validationError() {
    if (!supportedLanguages.contains(language)) {
      return 'Выберите поддерживаемый язык словаря';
    }

    final normalizedTemplate = template.trim();
    if (!normalizedTemplate.contains('{word}')) {
      return 'Адрес должен содержать {word}';
    }
    if (normalizedTemplate.contains('{') || normalizedTemplate.contains('}')) {
      final withoutKnownPlaceholders = normalizedTemplate
          .replaceAll('{word}', '')
          .replaceAll('{lang}', '');
      if (withoutKnownPlaceholders.contains('{') || withoutKnownPlaceholders.contains('}')) {
        return 'Адрес содержит неподдерживаемый шаблон';
      }
    }

    final Uri uri;
    try {
      uri = Uri.parse(
        normalizedTemplate
            .replaceAll('{word}', _wordMarker)
            .replaceAll('{lang}', _languageMarker),
      );
    } on FormatException {
      return 'Введите корректный адрес словаря';
    }

    if (uri.userInfo.isNotEmpty ||
        uri.queryParameters.keys.any(_sensitiveQueryParameter.hasMatch)) {
      return 'Адрес словаря не должен содержать учётные данные';
    }
    if (uri.scheme == 'https' && uri.host.isNotEmpty) return null;
    if (uri.scheme == 'http' && _isExplicitlyLocalHost(uri.host)) return null;
    return 'Разрешены только HTTPS или локальный HTTP-адрес';
  }

  Uri resolve(String word) {
    final error = validationError();
    if (error != null) throw FormatException(error);

    return Uri.parse(
      template
          .trim()
          .replaceAll('{word}', Uri.encodeComponent(word))
          .replaceAll('{lang}', language),
    );
  }

  static bool _isExplicitlyLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}

/// Persists only the non-sensitive URL template selected by the reader owner.
class DictionaryLookupSourceStore {
  const DictionaryLookupSourceStore(this._preferences);

  static const _key = 'reader_dictionary_lookup_source';

  final SharedPreferences _preferences;

  static Future<DictionaryLookupSourceStore> open() async {
    return DictionaryLookupSourceStore(await SharedPreferences.getInstance());
  }

  DictionaryLookupSource? load() {
    final encoded = _preferences.getString(_key);
    if (encoded == null) return null;

    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return null;
      final template = value['template'];
      final language = value['language'];
      if (template is! String || language is! String) return null;

      final source = DictionaryLookupSource(template: template, language: language);
      return source.validationError() == null ? source : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(DictionaryLookupSource source) async {
    final error = source.validationError();
    if (error != null) throw FormatException(error);

    await _preferences.setString(
      _key,
      jsonEncode(<String, String>{
        'template': source.template.trim(),
        'language': source.language,
      }),
    );
  }

  Future<void> clear() => _preferences.remove(_key);
}

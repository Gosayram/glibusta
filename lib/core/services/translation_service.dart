import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationBackend { googleWeb, bingWeb, deepl }

enum TranslationMode { off, translationOnly, originalOnly, bilingual }

class TranslationResult {
  const TranslationResult({
    required this.translatedText,
    this.detectedLanguage,
    this.originalText = '',
  });

  final String translatedText;
  final String? detectedLanguage;
  final String originalText;
}

abstract class TranslateServiceProvider {
  Future<TranslationResult> translate(String text, {String? from, String? to});
  Stream<String> translateStream(String text, {String? from, String? to});
}

class GoogleWebTranslator extends TranslateServiceProvider {
  GoogleWebTranslator(this._dio);

  final Dio _dio;

  @override
  Future<TranslationResult> translate(
    String text, {
    String? from,
    String? to,
  }) async {
    final url = 'https://translate.googleapis.com/translate_a/single';
    final response = await _dio.get<dynamic>(
      url,
      queryParameters: {
        'client': 'gtx',
        'sl': from ?? 'auto',
        'tl': to ?? 'ru',
        'dt': 't',
        'q': text,
      },
    );

    final data = response.data;
    if (data is List && data.isNotEmpty) {
      final sentences = data[0] as List;
      final translated = sentences.map((s) {
        final row = s as List;
        return row[0] as String? ?? '';
      }).join();
      return TranslationResult(
        translatedText: translated,
        detectedLanguage: data[2] as String?,
        originalText: text,
      );
    }
    return TranslationResult(translatedText: text, originalText: text);
  }

  @override
  Stream<String> translateStream(String text, {String? from, String? to}) async* {
    final result = await translate(text, from: from, to: to);
    yield result.translatedText;
  }
}

class BingWebTranslator extends TranslateServiceProvider {
  BingWebTranslator(this._dio);

  final Dio _dio;

  @override
  Future<TranslationResult> translate(
    String text, {
    String? from,
    String? to,
  }) async {
    final url = 'https://api.cognitive.microsofttranslator.com/translate';
    final response = await _dio.post<dynamic>(
      url,
      queryParameters: {
        'api-version': '3.0',
        'from': from ?? 'en',
        'to': to ?? 'ru',
      },
      data: [
        {'Text': text},
      ],
    );

    final data = response.data;
    if (data is List && data.isNotEmpty) {
      final first = data[0] as Map<String, dynamic>;
      final translations = first['translations'] as List;
      if (translations.isNotEmpty) {
        final entry = translations[0] as Map<String, dynamic>;
        return TranslationResult(
          translatedText: entry['text'] as String,
          detectedLanguage:
              (first['detectedLanguage'] as Map<String, dynamic>?)?['language'] as String?,
          originalText: text,
        );
      }
    }
    return TranslationResult(translatedText: text, originalText: text);
  }

  @override
  Stream<String> translateStream(String text, {String? from, String? to}) async* {
    final result = await translate(text, from: from, to: to);
    yield result.translatedText;
  }
}

class TranslationService {
  TranslationService(this._prefs, this._dio);

  final SharedPreferences _prefs;
  final Dio _dio;
  static const _settingsKey = 'translation_settings';

  TranslationBackend _backend = TranslationBackend.googleWeb;
  TranslationMode _mode = TranslationMode.off;
  String _fromLang = 'auto';
  String _toLang = 'ru';
  bool _autoTranslate = false;

  TranslationBackend get backend => _backend;
  TranslationMode get mode => _mode;
  String get fromLang => _fromLang;
  String get toLang => _toLang;
  bool get autoTranslate => _autoTranslate;

  TranslateServiceProvider get _provider {
    switch (_backend) {
      case TranslationBackend.googleWeb:
        return GoogleWebTranslator(_dio);
      case TranslationBackend.bingWeb:
        return BingWebTranslator(_dio);
      case TranslationBackend.deepl:
        return GoogleWebTranslator(_dio);
    }
  }

  void init() {
    final json = _prefs.getString(_settingsKey);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _backend = TranslationBackend.values[map['backend'] as int? ?? 0];
      _mode = TranslationMode.values[map['mode'] as int? ?? 0];
      _fromLang = map['fromLang'] as String? ?? 'auto';
      _toLang = map['toLang'] as String? ?? 'ru';
      _autoTranslate = map['autoTranslate'] as bool? ?? false;
    } on Object catch (_) {}
  }

  Future<void> _saveSettings() async {
    final map = {
      'backend': _backend.index,
      'mode': _mode.index,
      'fromLang': _fromLang,
      'toLang': _toLang,
      'autoTranslate': _autoTranslate,
    };
    await _prefs.setString(_settingsKey, jsonEncode(map));
  }

  Future<void> setBackend(TranslationBackend backend) async {
    _backend = backend;
    await _saveSettings();
  }

  Future<void> setMode(TranslationMode mode) async {
    _mode = mode;
    await _saveSettings();
  }

  Future<void> setLanguages({String? from, String? to}) async {
    if (from != null) _fromLang = from;
    if (to != null) _toLang = to;
    await _saveSettings();
  }

  Future<void> setAutoTranslate(bool enabled) async {
    _autoTranslate = enabled;
    await _saveSettings();
  }

  Future<TranslationResult> translate(String text) {
    return _provider.translate(text, from: _fromLang, to: _toLang);
  }

  Stream<String> translateStream(String text) {
    return _provider.translateStream(text, from: _fromLang, to: _toLang);
  }
}

const supportedLanguages = [
  ('auto', 'Автоопределение'),
  ('ru', 'Русский'),
  ('en', 'Английский'),
  ('zh', 'Китайский'),
  ('ja', 'Японский'),
  ('ko', 'Корейский'),
  ('de', 'Немецкий'),
  ('fr', 'Французский'),
  ('es', 'Испанский'),
  ('it', 'Итальянский'),
  ('pt', 'Португальский'),
  ('tr', 'Турецкий'),
  ('ar', 'Арабский'),
  ('hi', 'Хинди'),
  ('th', 'Тайский'),
  ('vi', 'Вьетнамский'),
];

final translationServiceProvider = Provider<TranslateServiceProvider>((ref) {
  return _NoOpTranslationService();
});

class _NoOpTranslationService extends TranslateServiceProvider {
  @override
  Future<TranslationResult> translate(
    String text, {
    String? from,
    String? to,
  }) async {
    return TranslationResult(translatedText: text, originalText: text);
  }

  @override
  Stream<String> translateStream(
    String text, {
    String? from,
    String? to,
  }) {
    return Stream.value(text);
  }
}

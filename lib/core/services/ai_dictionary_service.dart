import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiDictionaryResult {
  const AiDictionaryResult({
    required this.word,
    required this.definition,
    this.pronunciation,
    this.examples = const [],
    this.synonyms = const [],
    this.translation,
  });

  final String word;
  final String definition;
  final String? pronunciation;
  final List<String> examples;
  final List<String> synonyms;
  final String? translation;
}

class AiDictionaryService {
  AiDictionaryService(this._dio);

  final Dio _dio;

  Future<AiDictionaryResult> lookup(String word, {String? bookContext}) async {
    try {
      final response = await _dio.post<dynamic>(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_getApiKey()}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a dictionary assistant. Return a JSON object with: '
                  '"definition" (string), "pronunciation" (string, optional), '
                  '"examples" (list of strings), "synonyms" (list of strings), '
                  '"translation" (string, optional, Russian translation).',
            },
            {
              'role': 'user',
              'content':
                  'Define the word "$word"${bookContext != null ? ' in the context of: $bookContext' : ''}',
            },
          ],
          'response_format': {'type': 'json_object'},
        },
      );

      final data = response.data;
      if (data is Map && data['choices'] is List) {
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final content = choices[0]['message']?['content'];
          if (content is String) {
            final json = _parseJson(content);
            return AiDictionaryResult(
              word: word,
              definition: json['definition'] as String? ?? '',
              pronunciation: json['pronunciation'] as String?,
              examples: (json['examples'] as List?)?.cast<String>() ?? [],
              synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
              translation: json['translation'] as String?,
            );
          }
        }
      }
    } on Object catch (_) {}

    return AiDictionaryResult(word: word, definition: 'Could not look up "$word"');
  }

  Map<String, dynamic> _parseJson(String content) {
    try {
      final cleaned = content.replaceFirst('```json', '').replaceFirst('```', '').trim();
      return Map<String, dynamic>.from(
        // ignore: avoid_dynamic_calls
        (Uri.dataFromString(cleaned).data as Object?) as Map? ?? {},
      );
    } on Object catch (_) {
      return {};
    }
  }

  String? _getApiKey() => null;
}

final aiDictionaryServiceProvider = Provider<AiDictionaryService>((ref) {
  return AiDictionaryService(Dio());
});

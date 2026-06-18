import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

enum AiToolType { searchBook, extractQuotes, analyzeCharacters, summarize }

class AiTool {
  const AiTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toFunctionSchema() => {
    'name': name,
    'description': description,
    'parameters': {
      'type': 'object',
      'properties': parameters,
    },
  };
}

class AiToolResult {
  const AiToolResult({
    required this.toolName,
    required this.content,
    this.success = true,
    this.error,
  });

  final String toolName;
  final String content;
  final bool success;
  final String? error;
}

class AiAgentService {
  AiAgentService(this._dio, this._apiKey);

  final Dio _dio;
  final String _apiKey;

  static const _tools = [
    AiTool(
      name: 'search_book',
      description: 'Search for specific text or keywords within the book',
      parameters: {
        'query': {'type': 'string', 'description': 'The search query'},
      },
    ),
    AiTool(
      name: 'extract_quotes',
      description: 'Extract notable quotes from the text',
      parameters: {
        'topic': {'type': 'string', 'description': 'The topic or theme to extract quotes about'},
      },
    ),
    AiTool(
      name: 'analyze_characters',
      description: 'Analyze characters in the text, their relationships and traits',
      parameters: {
        'character_name': {
          'type': 'string',
          'description': 'Optional specific character to analyze',
        },
      },
    ),
    AiTool(
      name: 'summarize',
      description: 'Summarize the provided text or chapter',
      parameters: {
        'max_length': {'type': 'integer', 'description': 'Maximum summary length in words'},
      },
    ),
  ];

  List<AiTool> get availableTools => _tools;

  Stream<String> chatWithTools({
    required String prompt,
    required String bookContext,
    List<Map<String, String>>? conversationHistory,
  }) async* {
    final messages = [
      {
        'role': 'system',
        'content':
            'You are an AI reading assistant. You help users understand books by searching, '
            'extracting quotes, analyzing characters, and summarizing. '
            'Always respond in the same language as the user.',
      },
      ...?conversationHistory,
      {
        'role': 'user',
        'content': 'Book context:\n$bookContext\n\nUser question: $prompt',
      },
    ];

    final response = await _dio.post<dynamic>(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': messages,
        'tools': _tools.map((t) => {'type': 'function', 'function': t.toFunctionSchema()}).toList(),
        'stream': true,
      }),
    );

    final data = response.data;
    if (data is Map && data['choices'] is List) {
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        final delta = choices[0]['delta'];
        if (delta is Map && delta['content'] is String) {
          yield delta['content'] as String;
        }
      }
    }
  }

  Future<AiToolResult> executeTool(
    String toolName,
    Map<String, dynamic> args,
    String bookText,
  ) async {
    switch (toolName) {
      case 'search_book':
        return _searchBook(args['query'] as String, bookText);
      case 'extract_quotes':
        return _extractQuotes(args['topic'] as String? ?? '', bookText);
      case 'analyze_characters':
        return _analyzeCharacters(args['character_name'] as String? ?? '', bookText);
      case 'summarize':
        return _summarize(bookText);
      default:
        return AiToolResult(
          toolName: toolName,
          content: '',
          success: false,
          error: 'Unknown tool',
        );
    }
  }

  AiToolResult _searchBook(String query, String bookText) {
    final lines = bookText.split('\n');
    final matches = <String>[];
    for (final line in lines) {
      if (line.toLowerCase().contains(query.toLowerCase())) {
        matches.add(line.trim());
      }
    }
    if (matches.isEmpty) {
      return const AiToolResult(toolName: 'search_book', content: 'Nothing found');
    }
    return AiToolResult(toolName: 'search_book', content: matches.join('\n'));
  }

  AiToolResult _extractQuotes(String topic, String bookText) {
    final sentences = bookText.split(RegExp(r'[.!?]+'));
    final quotes = sentences
        .where(
          (s) =>
              s.trim().length > 30 &&
              (topic.isEmpty || s.toLowerCase().contains(topic.toLowerCase())),
        )
        .take(5)
        .map((s) => '"${s.trim()}."')
        .toList();
    return AiToolResult(
      toolName: 'extract_quotes',
      content: quotes.isEmpty ? 'No quotes found' : quotes.join('\n\n'),
    );
  }

  AiToolResult _analyzeCharacters(String characterName, String bookText) {
    final buffer = StringBuffer('Character analysis:\n');
    if (characterName.isNotEmpty) {
      buffer.writeln('Analyzing: $characterName');
      final sentences = bookText.split('\n');
      final relevant = sentences
          .where((s) => s.toLowerCase().contains(characterName.toLowerCase()))
          .take(10)
          .toList();
      buffer.writeln('Found ${relevant.length} mentions.');
    } else {
      buffer.writeln('Please specify a character name to analyze.');
    }
    return AiToolResult(toolName: 'analyze_characters', content: buffer.toString());
  }

  AiToolResult _summarize(String bookText) {
    final words = bookText.split(RegExp(r'\s+'));
    final summaryWords = words.take(200).join(' ');
    return AiToolResult(toolName: 'summarize', content: '$summaryWords...');
  }
}

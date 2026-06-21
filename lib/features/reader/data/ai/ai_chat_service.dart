import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiPanelMode { adaptive, alwaysPopup, alwaysSplit }

enum AiPromptType { summarizeChapter, summarizeBook, mindMap, explain, translate, custom }

class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final String role;
  final String content;
  final bool isStreaming;

  AiMessage copyWith({String? content, bool? isStreaming}) {
    return AiMessage(
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class AiPanelSettings {
  const AiPanelSettings({
    this.mode = AiPanelMode.adaptive,
    this.splitRatio = 0.4,
    this.customPrompts = const [],
  });

  final AiPanelMode mode;
  final double splitRatio;
  final List<String> customPrompts;

  AiPanelSettings copyWith({
    AiPanelMode? mode,
    double? splitRatio,
    List<String>? customPrompts,
  }) {
    return AiPanelSettings(
      mode: mode ?? this.mode,
      splitRatio: splitRatio ?? this.splitRatio,
      customPrompts: customPrompts ?? this.customPrompts,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.index,
    'splitRatio': splitRatio,
    'customPrompts': customPrompts,
  };

  factory AiPanelSettings.fromJson(Map<String, dynamic> json) => AiPanelSettings(
    mode: AiPanelMode.values[json['mode'] as int? ?? 0],
    splitRatio: (json['splitRatio'] as num?)?.toDouble() ?? 0.4,
    customPrompts: (json['customPrompts'] as List?)?.cast<String>() ?? [],
  );
}

class AiChatService {
  AiChatService(this._prefs);

  final SharedPreferences _prefs;
  static const _settingsKey = 'ai_panel_settings';
  static const _historyKey = 'ai_chat_history';

  final _messagesController = StreamController<List<AiMessage>>.broadcast();
  Stream<List<AiMessage>> get onMessagesChange => _messagesController.stream;

  List<AiMessage> _messages = [];
  List<AiMessage> get messages => List.unmodifiable(_messages);

  AiPanelSettings _settings = const AiPanelSettings();
  AiPanelSettings get settings => _settings;

  void init() {
    _settings = _loadSettings();
    _messages = _loadHistory();
    _messagesController.add(_messages);
  }

  AiPanelSettings _loadSettings() {
    final json = _prefs.getString(_settingsKey);
    if (json == null) return const AiPanelSettings();
    try {
      return AiPanelSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (_) {
      return const AiPanelSettings();
    }
  }

  List<AiMessage> _loadHistory() {
    final json = _prefs.getString(_historyKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map(
        (e) {
          final map = e as Map<String, dynamic>;
          return AiMessage(
            role: map['role'] as String,
            content: map['content'] as String,
          );
        },
      ).toList();
    } on Object catch (_) {
      return [];
    }
  }

  Future<void> _saveSettings() async {
    await _prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }

  Future<void> _saveHistory() async {
    final json = _messages.map((m) => {'role': m.role, 'content': m.content}).toList();
    await _prefs.setString(_historyKey, jsonEncode(json));
  }

  Future<void> updateSettings(AiPanelSettings settings) async {
    _settings = settings;
    await _saveSettings();
  }

  void addCustomPrompt(String prompt) {
    final prompts = List<String>.from(_settings.customPrompts)..add(prompt);
    unawaited(updateSettings(_settings.copyWith(customPrompts: prompts)));
  }

  void removeCustomPrompt(int index) {
    final prompts = List<String>.from(_settings.customPrompts)..removeAt(index);
    unawaited(updateSettings(_settings.copyWith(customPrompts: prompts)));
  }

  String buildPrompt(
    AiPromptType type, {
    String? chapterText,
    String? bookText,
    String? selectedText,
  }) {
    switch (type) {
      case AiPromptType.summarizeChapter:
        return 'Подведи итог этой главы. Выдели ключевые моменты и выводы.\n\n$chapterText';
      case AiPromptType.summarizeBook:
        return 'Подведи итог этой книги. Основные идеи, тезисы и выводы.\n\n$bookText';
      case AiPromptType.mindMap:
        return 'Составь карту мыслей (mind map) для этой главы. Структурируй по темам.\n\n$chapterText';
      case AiPromptType.explain:
        return 'Объясни подробнее:\n\n${selectedText ?? ""}';
      case AiPromptType.translate:
        return 'Переведи на русский:\n\n${selectedText ?? ""}';
      case AiPromptType.custom:
        return selectedText ?? '';
    }
  }

  Future<void> sendMessage(String prompt, {Stream<String>? responseStream}) async {
    _messages.add(AiMessage(role: 'user', content: prompt));
    _messagesController.add(_messages);

    const aiMessage = AiMessage(role: 'assistant', content: '', isStreaming: true);
    _messages.add(aiMessage);
    _messagesController.add(_messages);

    if (responseStream != null) {
      final buffer = StringBuffer();
      await for (final chunk in responseStream) {
        buffer.write(chunk);
        final idx = _messages.length - 1;
        _messages[idx] = _messages[idx].copyWith(content: buffer.toString());
        _messagesController.add(_messages);
      }
      _messages[_messages.length - 1] = _messages.last.copyWith(isStreaming: false);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _messages[_messages.length - 1] = _messages.last.copyWith(
        content: 'AI ответ будет здесь. Подключите провайдер API для реальных ответов.',
        isStreaming: false,
      );
    }

    _messagesController.add(_messages);
    await _saveHistory();
  }

  void clearHistory() {
    _messages.clear();
    _messagesController.add(_messages);
    unawaited(_saveHistory());
  }

  void dispose() {
    unawaited(_messagesController.close());
  }
}

final aiChatServiceProvider = Provider<AiChatService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = AiChatService(prefs);
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden at startup with a SharedPreferences instance.',
  );
});

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/tts_controller.dart';
import '../../../core/utils/monotonic_id.dart';
import '../data/dictionary_lookup_history.dart';
import '../data/dictionary_lookup_preview.dart';
import '../data/dictionary_lookup_source.dart';
import '../data/highlight_decoration.dart';

class ReaderSelectionToolbar extends ConsumerStatefulWidget {
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final String selectedText;
  final VoidCallback onDismiss;
  final ValueChanged<String>? onSearchInBook;
  final TtsController? ttsController;

  const ReaderSelectionToolbar({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.selectedText,
    required this.onDismiss,
    this.onSearchInBook,
    this.ttsController,
  });

  @override
  ConsumerState<ReaderSelectionToolbar> createState() => _ReaderSelectionToolbarState();
}

class _ReaderSelectionToolbarState extends ConsumerState<ReaderSelectionToolbar> {
  String? _selectedText;

  TtsController get _ttsController => widget.ttsController ?? TtsController.instance;

  @override
  void initState() {
    super.initState();
    _selectedText = widget.selectedText;
  }

  @override
  void didUpdateWidget(covariant ReaderSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedText != oldWidget.selectedText) {
      _selectedText = widget.selectedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.copy,
                label: 'Копировать',
                onTap: () async {
                  if (_selectedText != null) {
                    await Clipboard.setData(ClipboardData(text: _selectedText!));
                    if (context.mounted) {
                      unawaited(SmartDialog.showToast('Текст скопирован'));
                    }
                  }
                  widget.onDismiss();
                },
              ),
              _ToolbarButton(
                icon: Icons.share,
                label: 'Поделиться',
                onTap: () async {
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    await SharePlus.instance.share(
                      ShareParams(text: _selectedText),
                    );
                  }
                  widget.onDismiss();
                },
              ),
              _ToolbarButton(
                icon: Icons.search,
                label: 'В поиске',
                onTap: () async {
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    final query = Uri.encodeComponent(_selectedText!);
                    final uri = Uri.parse('https://www.google.com/search?q=$query');
                    try {
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && context.mounted) {
                        unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                      }
                    } on Object {
                      if (context.mounted) {
                        unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                      }
                    }
                  }
                  widget.onDismiss();
                },
              ),
              // HG-7.5: in-book search from context
              if (widget.onSearchInBook != null && _selectedText != null)
                _ToolbarButton(
                  icon: Icons.menu_book,
                  label: 'В книге',
                  onTap: () {
                    widget.onSearchInBook!(_selectedText!);
                    widget.onDismiss();
                  },
                ),
              _ToolbarButton(
                icon: Icons.translate,
                label: 'Перевод',
                onTap: () async {
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    final query = Uri.encodeComponent(_selectedText!);
                    final uri = Uri.parse(
                      'https://translate.google.com/?sl=auto&tl=ru&text=$query',
                    );
                    try {
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && context.mounted) {
                        unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                      }
                    } on Object {
                      if (context.mounted) {
                        unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                      }
                    }
                  }
                  widget.onDismiss();
                },
              ),
              // An online lookup is always explicitly confirmed before the
              // selected text is sent to the configured source.
              _ToolbarButton(
                icon: Icons.menu_book,
                label: 'Словарь',
                onTap: () async {
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    final query = _selectedText!.trim();
                    if (context.mounted) {
                      unawaited(_startDictionaryLookup(context, query));
                    }
                  }
                  widget.onDismiss();
                },
              ),
              _ToolbarButton(
                icon: Icons.history,
                label: 'История',
                onTap: () async {
                  await _showDictionaryHistory(context);
                  if (mounted) widget.onDismiss();
                },
              ),
              _ToolbarButton(
                icon: Icons.tune,
                label: 'Источник',
                onTap: () => unawaited(_showDictionarySourceEditor()),
              ),
              // HG-7.7: Wikipedia search
              _ToolbarButton(
                icon: Icons.language,
                label: 'Википедия',
                onTap: () async {
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    final query = Uri.encodeComponent(_selectedText!);
                    final uri = Uri.parse('https://ru.wikipedia.org/wiki/$query');
                    try {
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && context.mounted) {
                        unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                      }
                    } on Object {
                      if (context.mounted) {
                        unawaited(SmartDialog.showToast('Не удалось открыть ссылку'));
                      }
                    }
                  }
                  widget.onDismiss();
                },
              ),
              // TTS: pause/resume keeps the platform's native progress, while
              // stop remains available as an explicit reset action.
              if (_selectedText != null && _selectedText!.isNotEmpty)
                _ToolbarButton(
                  icon: _ttsController.isPlaying
                      ? Icons.pause_circle_outline
                      : _ttsController.isPaused
                      ? Icons.play_circle_outline
                      : Icons.volume_up,
                  label: _ttsController.isPlaying
                      ? 'Пауза'
                      : _ttsController.isPaused
                      ? 'Продолжить'
                      : 'Озвучить',
                  onTap: () {
                    if (_ttsController.isPlaying) {
                      unawaited(_pauseSelectedText());
                    } else if (_ttsController.isPaused) {
                      unawaited(_resumeSelectedText());
                    } else {
                      unawaited(_speakSelectedText(_selectedText!));
                    }
                  },
                ),
              if (_selectedText != null &&
                  _selectedText!.isNotEmpty &&
                  (_ttsController.isPlaying || _ttsController.isPaused))
                _ToolbarButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'Остановить',
                  onTap: () {
                    _ttsController.stop();
                    setState(() {});
                  },
                ),
              _ToolbarButton(
                icon: Icons.speed,
                label: _playbackSpeedLabel,
                onTap: () => unawaited(_showPlaybackSpeedSheet()),
              ),
              _ToolbarButton(
                icon: Icons.record_voice_over_outlined,
                label: _speechLanguageLabel,
                onTap: () => unawaited(_showSpeechLanguageSheet()),
              ),
              _ToolbarButton(
                icon: _ttsController.hasSleepTimer ? Icons.timer : Icons.timer_outlined,
                label: _sleepTimerLabel,
                onTap: () => unawaited(_showSleepTimerSheet()),
              ),
              _ToolbarButton(
                icon: Icons.bookmark_add,
                label: 'Закладка',
                onTap: () => unawaited(_addBookmark(context)),
              ),
              _ToolbarButton(
                icon: Icons.sticky_note_2,
                label: 'Заметка',
                onTap: () => unawaited(_addNote(context)),
              ),
              _ToolbarButton(
                icon: Icons.format_quote,
                label: 'Цитата',
                onTap: () => unawaited(_addQuote(context)),
              ),
              _ToolbarButton(
                icon: Icons.highlight,
                label: 'Выделить',
                onTap: () => unawaited(_pickHighlightColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addBookmark(BuildContext context) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: '${widget.bookId}-${newMonotonicId()}',
            bookId: widget.bookId,
            chapterIndex: widget.chapterIndex,
            paragraphIndex: widget.paragraphIndex,
            selectedText: Value(_selectedText),
          ),
        );
    if (context.mounted) {
      unawaited(SmartDialog.showToast('Закладка добавлена'));
    }
    widget.onDismiss();
  }

  Future<void> _addNote(BuildContext context) async {
    final textController = TextEditingController(text: _selectedText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedText != null && _selectedText!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedText!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Введите заметку...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final db = ref.read(databaseProvider);
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: '${widget.bookId}-${newMonotonicId()}',
              bookId: widget.bookId,
              chapterIndex: widget.chapterIndex,
              paragraphIndex: widget.paragraphIndex,
              content: result,
            ),
          );
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Заметка сохранена'));
      }
    }
    widget.onDismiss();
  }

  Future<void> _addQuote(BuildContext context) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Цитата'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                _selectedText!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Комментарий (необязательно)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final db = ref.read(databaseProvider);
      await db
          .into(db.quotes)
          .insert(
            QuotesCompanion.insert(
              id: '${widget.bookId}-${newMonotonicId()}',
              bookId: widget.bookId,
              chapterIndex: widget.chapterIndex,
              paragraphIndex: widget.paragraphIndex,
              selectedText: _selectedText!,
              note: result.isNotEmpty ? Value(result) : const Value.absent(),
            ),
          );
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Цитата сохранена'));
      }
    }
    widget.onDismiss();
  }

  Future<void> _pickHighlightColor(BuildContext context) async {
    final result = await showModalBottomSheet<(_HighlightColor, HighlightDecoration)>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => _HighlightPickerSheet(),
    );

    if (!mounted || result == null) return;
    await _addHighlight(result.$1.id, result.$2);
  }

  Future<void> _addHighlight(String color, HighlightDecoration decoration) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db
        .into(db.textHighlights)
        .insert(
          TextHighlightsCompanion.insert(
            id: '${widget.bookId}-${newMonotonicId()}',
            bookId: widget.bookId,
            chapterId: widget.chapterIndex.toString(),
            chapterIndex: widget.chapterIndex,
            blockIndex: widget.paragraphIndex,
            startOffset: 0,
            endOffset: _selectedText!.length,
            selectedText: _selectedText!,
            color: Value(color),
            decoration: Value(decoration.toDbValue()),
          ),
        );
    if (mounted) {
      unawaited(SmartDialog.showToast('Текст выделен'));
    }
    widget.onDismiss();
  }

  Future<void> _startDictionaryLookup(BuildContext context, String query) async {
    final sourceStore = await DictionaryLookupSourceStore.open();
    final source = sourceStore.load();
    if (!context.mounted) return;

    final host = source?.resolve(query).host ?? 'en.wiktionary.org';
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Онлайн-словарь'),
        content: Text(
          DictionaryLookupPreview.confirmationMessage(
            host: host,
            query: query,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (shouldContinue != true || !context.mounted) return;

    unawaited(_recordDictionaryQuery(query));
    if (source != null) {
      try {
        final launched = await launchUrl(
          source.resolve(query),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          unawaited(SmartDialog.showToast('Не удалось открыть словарь'));
        }
      } on FormatException catch (e) {
        debugPrint('Dictionary source error: $e');
        if (context.mounted) {
          unawaited(SmartDialog.showToast('Адрес словаря больше не подходит'));
        }
      } on Object catch (e) {
        debugPrint('Dictionary launch error: $e');
        if (context.mounted) {
          unawaited(SmartDialog.showToast('Не удалось открыть словарь'));
        }
      }
      return;
    }

    await _showWiktionaryPopup(context, query);
  }

  // The built-in source remains useful for concise in-reader definitions.
  Future<void> _showWiktionaryPopup(BuildContext context, String query) async {
    try {
      final client = HttpClient();
      final uri = Uri.https(
        'en.wiktionary.org',
        '/api/rest_v1/page/summary/${Uri.encodeComponent(query)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      if (!context.mounted) {
        client.close();
        return;
      }

      if (response.statusCode != 200) {
        client.close();
        unawaited(SmartDialog.showToast('Ничего не найдено'));
        return;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final title = data['title'] as String? ?? query;
      final extract = data['extract'] as String? ?? '';

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(extract.isNotEmpty ? extract : 'Нет определения'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Ошибка словаря: $e'));
      }
    }
  }

  Future<void> _recordDictionaryQuery(String query) async {
    try {
      final history = await DictionaryLookupHistory.open();
      await history.record(query);
    } on Object catch (e) {
      debugPrint('Dictionary history save failed: $e');
    }
  }

  Future<void> _showDictionarySourceEditor() async {
    final sourceStore = await DictionaryLookupSourceStore.open();
    final currentSource = sourceStore.load();
    if (!mounted) return;

    final templateController = TextEditingController(text: currentSource?.template ?? '');
    var language = currentSource?.language ?? 'en';
    String? validationError;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Источник словаря'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Пустое поле использует встроенный Wiktionary. '
                    'Запрос передаётся выбранному источнику только после подтверждения.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: templateController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'URL-шаблон',
                      hintText: 'https://example.org/lookup/{word}?lang={lang}',
                      errorText: validationError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: language,
                    decoration: const InputDecoration(labelText: 'Язык словаря'),
                    items: [
                      for (final item in DictionaryLookupSource.supportedLanguages.toList()..sort())
                        DropdownMenuItem(value: item, child: Text(item.toUpperCase())),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => language = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Допускаются HTTPS и локальный HTTP (localhost, 127.0.0.1, ::1). '
                    'Шаблон обязан содержать {word}; {lang} необязателен.',
                  ),
                ],
              ),
            ),
            actions: [
              if (currentSource != null)
                TextButton(
                  onPressed: () async {
                    await sourceStore.clear();
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Сбросить'),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () async {
                  final template = templateController.text.trim();
                  if (template.isEmpty) {
                    await sourceStore.clear();
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    return;
                  }

                  final source = DictionaryLookupSource(
                    template: template,
                    language: language,
                  );
                  final error = source.validationError();
                  if (error != null) {
                    setDialogState(() => validationError = error);
                    return;
                  }

                  await sourceStore.save(source);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      );
    } finally {
      templateController.dispose();
    }
  }

  Future<void> _showDictionaryHistory(BuildContext context) async {
    try {
      final history = await DictionaryLookupHistory.open();
      var entries = history.entries();
      if (!context.mounted) return;

      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('История словаря'),
            content: SizedBox(
              width: double.maxFinite,
              child: entries.isEmpty
                  ? const Text('Пока нет запросов')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(entry, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.of(dialogContext).pop(entry),
                          trailing: IconButton(
                            tooltip: 'Удалить из истории',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await history.remove(entry);
                              entries = history.entries();
                              if (context.mounted) setDialogState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await history.clear();
                    entries = history.entries();
                    if (context.mounted) setDialogState(() {});
                  },
                  child: const Text('Очистить'),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      );

      if (selected != null && context.mounted) {
        await _startDictionaryLookup(context, selected);
      }
    } on Object catch (e) {
      debugPrint('Dictionary history error: $e');
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Не удалось открыть историю словаря'));
      }
    }
  }

  Future<void> _speakSelectedText(String text) async {
    try {
      await _ttsController.speak(text);
      if (mounted) setState(() {});
    } on Object catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _pauseSelectedText() async {
    try {
      await _ttsController.pause();
      if (mounted) setState(() {});
    } on Object catch (e) {
      debugPrint('TTS pause error: $e');
      if (mounted) unawaited(SmartDialog.showToast('Не удалось поставить озвучивание на паузу'));
    }
  }

  Future<void> _resumeSelectedText() async {
    try {
      await _ttsController.resume();
      if (mounted) setState(() {});
    } on Object catch (e) {
      debugPrint('TTS resume error: $e');
      if (mounted) unawaited(SmartDialog.showToast('Не удалось продолжить озвучивание'));
    }
  }

  String get _playbackSpeedLabel => 'Скорость: ${_formatPlaybackRate(_ttsController.playbackRate)}';

  String get _speechLanguageLabel => 'Язык: ${_speechLanguageName(_ttsController.language)}';

  Future<void> _showPlaybackSpeedSheet() async {
    final double? rate = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: RadioGroup<double>(
          groupValue: _ttsController.playbackRate,
          onChanged: (double? selectedRate) {
            if (selectedRate != null) Navigator.of(sheetContext).pop(selectedRate);
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                leading: Icon(Icons.speed),
                title: Text('Скорость озвучивания'),
                subtitle: Text('Применится к следующему фрагменту, не прерывая текущий'),
              ),
              for (final double playbackRate in _playbackRates)
                RadioListTile<double>(
                  value: playbackRate,
                  title: Text(_formatPlaybackRate(playbackRate)),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || rate == null) return;

    try {
      await _ttsController.setPlaybackRate(rate);
      if (mounted) setState(() {});
    } on Object catch (e) {
      debugPrint('TTS playback speed error: $e');
    }
  }

  Future<void> _showSpeechLanguageSheet() async {
    final String? language = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: _ttsController.language,
          onChanged: (String? selectedLanguage) {
            if (selectedLanguage != null) Navigator.of(sheetContext).pop(selectedLanguage);
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                leading: Icon(Icons.record_voice_over_outlined),
                title: Text('Язык озвучивания'),
                subtitle: Text('Применится к следующему фрагменту, не прерывая текущий'),
              ),
              for (final _SpeechLanguage speechLanguage in _speechLanguages)
                RadioListTile<String>(
                  value: speechLanguage.code,
                  title: Text(speechLanguage.name),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || language == null) return;

    try {
      await _ttsController.setLanguage(language);
      if (mounted) setState(() {});
    } on Object catch (e) {
      debugPrint('TTS language error: $e');
      if (mounted) {
        unawaited(SmartDialog.showToast('Этот язык озвучивания недоступен на устройстве'));
      }
    }
  }

  String get _sleepTimerLabel {
    final Duration? duration = _ttsController.sleepTimerDuration;
    if (duration == null) return 'Таймер сна';
    return 'Таймер: ${duration.inMinutes} мин';
  }

  Future<void> _showSleepTimerSheet() async {
    final _SleepTimerAction? action = await showModalBottomSheet<_SleepTimerAction>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              leading: Icon(Icons.timer_outlined),
              title: Text('Таймер сна'),
              subtitle: Text('Остановит озвучивание через выбранное время'),
            ),
            for (final Duration duration in _sleepTimerDurations)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('${duration.inMinutes} минут'),
                onTap: () => Navigator.of(sheetContext).pop(
                  _SleepTimerAction.start(duration),
                ),
              ),
            if (_ttsController.hasSleepTimer)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('Отключить таймер сна'),
                onTap: () => Navigator.of(sheetContext).pop(const _SleepTimerAction.cancel()),
              ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _SleepTimerAction(:final duration?):
        _ttsController.startSleepTimer(duration);
      case _SleepTimerAction(duration: null):
        _ttsController.cancelSleepTimer();
    }
    setState(() {});
  }
}

const List<Duration> _sleepTimerDurations = <Duration>[
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 60),
];

const List<double> _playbackRates = <double>[0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3];

const List<_HighlightColor> _highlightColors = <_HighlightColor>[
  _HighlightColor(id: 'yellow', name: 'Жёлтый', value: Color(0xFFFFEB3B)),
  _HighlightColor(id: 'green', name: 'Зелёный', value: Color(0xFF81C784)),
  _HighlightColor(id: 'blue', name: 'Синий', value: Color(0xFF90CAF9)),
  _HighlightColor(id: 'pink', name: 'Розовый', value: Color(0xFFF48FB1)),
];

const List<(HighlightDecoration, String)> _highlightDecorations =
    <
      (
        HighlightDecoration,
        String,
      )
    >[
      (HighlightDecoration.none, 'Без стиля'),
      (HighlightDecoration.underline, 'Подчёркивание'),
      (HighlightDecoration.strikethrough, 'Зачёркивание'),
    ];

class _HighlightPickerSheet extends StatefulWidget {
  @override
  State<_HighlightPickerSheet> createState() => _HighlightPickerSheetState();
}

class _HighlightPickerSheetState extends State<_HighlightPickerSheet> {
  HighlightDecoration _selectedDecoration = HighlightDecoration.none;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            leading: Icon(Icons.highlight),
            title: Text('Цвет выделения'),
            subtitle: Text('Выберите цвет и стиль для сохранения фрагмента'),
          ),
          for (final _HighlightColor color in _highlightColors)
            Semantics(
              label: 'Цвет выделения: ${color.name}',
              button: true,
              child: ExcludeSemantics(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color.value),
                  title: Text(color.name),
                  onTap: () => Navigator.of(context).pop(
                    (color, _selectedDecoration),
                  ),
                ),
              ),
            ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.format_underline),
            title: Text('Стиль выделения'),
          ),
          for (final (decoration, label) in _highlightDecorations)
            ListTile(
              leading: Icon(
                _selectedDecoration == decoration
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(label),
              onTap: () => setState(() => _selectedDecoration = decoration),
            ),
        ],
      ),
    );
  }
}

const List<_SpeechLanguage> _speechLanguages = <_SpeechLanguage>[
  _SpeechLanguage(code: 'ru-RU', name: 'Русский'),
  _SpeechLanguage(code: 'en-US', name: 'English'),
];

String _speechLanguageName(String code) => switch (code) {
  'ru-RU' => 'Русский',
  'en-US' => 'English',
  _ => code,
};

String _formatPlaybackRate(double rate) {
  final String value = rate == rate.roundToDouble()
      ? rate.toInt().toString()
      : rate.toStringAsFixed(rate == 0.75 || rate == 1.25 ? 2 : 1);
  return '$value×';
}

@immutable
class _SleepTimerAction {
  const _SleepTimerAction.start(this.duration);
  const _SleepTimerAction.cancel() : duration = null;

  final Duration? duration;
}

@immutable
class _SpeechLanguage {
  const _SpeechLanguage({required this.code, required this.name});

  final String code;
  final String name;
}

@immutable
class _HighlightColor {
  const _HighlightColor({required this.id, required this.name, required this.value});

  final String id;
  final String name;
  final Color value;
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

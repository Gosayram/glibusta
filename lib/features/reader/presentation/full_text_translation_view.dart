import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/translation_service.dart';

class FullTextTranslationView extends ConsumerStatefulWidget {
  const FullTextTranslationView({
    required this.originalText,
    required this.fromLang,
    required this.toLang,
    super.key,
  });

  final String originalText;
  final String fromLang;
  final String toLang;

  static Future<void> show({
    required BuildContext context,
    required String originalText,
    String fromLang = 'auto',
    String toLang = 'ru',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullTextTranslationView(
          originalText: originalText,
          fromLang: fromLang,
          toLang: toLang,
        ),
      ),
    );
  }

  @override
  ConsumerState<FullTextTranslationView> createState() => _FullTextTranslationViewState();
}

class _FullTextTranslationViewState extends ConsumerState<FullTextTranslationView> {
  String? _translatedText;
  bool _isLoading = true;
  bool _sideBySide = true;

  @override
  void initState() {
    super.initState();
    unawaited(_translate());
  }

  Future<void> _translate() async {
    setState(() {
      _isLoading = true;
      _translatedText = null;
    });

    try {
      final result = await ref
          .read(translationServiceProvider)
          .translate(
            widget.originalText,
          );
      if (mounted) {
        setState(() {
          _translatedText = result.translatedText;
          _isLoading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = 'Ошибка перевода: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Перевод главы'),
        actions: [
          IconButton(
            icon: Icon(_sideBySide ? Icons.view_agenda : Icons.view_week),
            onPressed: () => setState(() => _sideBySide = !_sideBySide),
            tooltip: _sideBySide ? 'Наложение' : 'Бок о бок',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sideBySide
          ? _buildSideBySide(theme)
          : _buildOverlay(theme),
    );
  }

  Widget _buildSideBySide(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Text('Оригинал', style: theme.textTheme.labelMedium),
                    const Spacer(),
                    Text(
                      widget.fromLang.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(widget.originalText, style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Text('Перевод', style: theme.textTheme.labelMedium),
                    const Spacer(),
                    Text(
                      widget.toLang.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _translatedText ?? '',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(ThemeData theme) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            _translatedText ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            child: Text(
              'Перевод поверх оригинала',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}

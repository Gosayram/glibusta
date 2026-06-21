import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/translation_service.dart';

class InlineTranslationSheet extends ConsumerStatefulWidget {
  const InlineTranslationSheet({
    required this.text,
    required this.fromLang,
    required this.toLang,
    super.key,
  });

  final String text;
  final String fromLang;
  final String toLang;

  static Future<void> show({
    required BuildContext context,
    required String text,
    String fromLang = 'auto',
    String toLang = 'ru',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: InlineTranslationSheet(
          text: text,
          fromLang: fromLang,
          toLang: toLang,
        ),
      ),
    );
  }

  @override
  ConsumerState<InlineTranslationSheet> createState() => _InlineTranslationSheetState();
}

class _InlineTranslationSheetState extends ConsumerState<InlineTranslationSheet> {
  String? _translatedText;
  bool _isLoading = true;

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
            widget.text,
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Оригинал',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.text, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 12),
            Text(
              'Перевод',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Text(
                      _translatedText ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

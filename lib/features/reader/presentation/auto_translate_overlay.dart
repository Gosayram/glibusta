import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/translation_service.dart';

class AutoTranslateOverlay extends ConsumerStatefulWidget {
  const AutoTranslateOverlay({
    required this.child,
    required this.fromLang,
    required this.toLang,
    this.debounceMs = 800,
    super.key,
  });

  final Widget child;
  final String fromLang;
  final String toLang;
  final int debounceMs;

  @override
  ConsumerState<AutoTranslateOverlay> createState() => _AutoTranslateOverlayState();
}

class _AutoTranslateOverlayState extends ConsumerState<AutoTranslateOverlay> {
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  String _lastSelectedText = '';

  @override
  void dispose() {
    _removeOverlay();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void onSelectionChanged(String selectedText) {
    if (selectedText.trim().isEmpty || selectedText == _lastSelectedText) return;
    _lastSelectedText = selectedText;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
      unawaited(_showTranslation(selectedText));
    });
  }

  Future<void> _showTranslation(String text) async {
    _removeOverlay();

    try {
      final result = await ref.read(translationServiceProvider).translate(text);

      if (!mounted) return;

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.translatedText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _removeOverlay,
                        child: const Text('Закрыть'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    } on Object catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
